# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/agenda_store"
require_relative "../lib/ge_client"
require_relative "../lib/ge_sync"

class GeSyncTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("agenda-sync-")
    @store = AgendaStore.new(File.join(@dir, "agenda.sqlite3"))
    @now = Time.parse("2026-11-11T09:00:00-03:00")
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def test_fetches_from_monday_of_the_week_through_today_plus_six
    client = recording_client
    result = GeSync.call(store: @store, client: client, now: @now)

    dates = (Date.new(2026, 11, 9)..Date.new(2026, 11, 17)).map(&:iso8601)
    assert_equal dates, client.futebol_dates
    assert_equal dates, client.multi_dates
    assert_equal 2, @store.tv_events_on(Date.new(2026, 11, 10)).size
    assert_equal "basquete", @store.tv_events_on(Date.new(2026, 11, 11)).find { |row| row[:sport] == "basquete" }[:sport]
    assert result[:ok]
    assert_equal "2026-11-09", result[:from]
    assert_equal "2026-11-17", result[:to]
    assert_equal 18, result[:upserted]
  end

  def test_monday_window_starts_today
    now = Time.parse("2026-11-09T09:00:00-03:00")
    client = recording_client
    result = GeSync.call(store: @store, client: client, now: now)

    dates = (Date.new(2026, 11, 9)..Date.new(2026, 11, 15)).map(&:iso8601)
    assert_equal dates, client.futebol_dates
    assert_equal "2026-11-09", result[:from]
    assert_equal "2026-11-15", result[:to]
  end

  def test_prunes_a_game_that_left_the_feed
    seed_day11("keep-me", "gone-me")
    client = recording_client(ids: { "2026-11-11" => ["keep-me"] })
    GeSync.call(store: @store, client: client, now: @now)

    ids = @store.tv_events_on(Date.new(2026, 11, 11)).map { |row| row[:ge_id] }
    assert_includes ids, "keep-me"
    refute_includes ids, "gone-me"
  end

  def test_failed_day_keeps_previous_rows
    seed_day11("old-11")
    client = recording_client(fail_dates: ["2026-11-11"])
    GeSync.call(store: @store, client: client, now: @now)

    assert_equal ["old-11"], @store.tv_events_on(Date.new(2026, 11, 11)).map { |row| row[:ge_id] }
    refute_empty @store.tv_events_on(Date.new(2026, 11, 12))
  end

  def test_total_failure_leaves_the_table_and_records_error
    seed_day11("old-11")
    client = recording_client(fail_dates: :all)

    error = assert_raises(GeSync::FetchError) do
      GeSync.call(store: @store, client: client, now: @now)
    end

    assert_match(/geql/i, error.message)
    assert_equal ["old-11"], @store.tv_events_on(Date.new(2026, 11, 11)).map { |row| row[:ge_id] }
    refute_nil @store.sync_state[:error]
  end

  def test_stale_after_twenty_hours
    @store.record_sync!(synced_at: @now - (19 * 3600), event_count: 3)
    refute GeSync.stale?(@store, now: @now)
    @store.record_sync!(synced_at: @now - (21 * 3600), event_count: 3)
    assert GeSync.stale?(@store, now: @now)
  end

  def test_never_synced_is_stale
    assert GeSync.stale?(@store, now: @now)
  end

  def test_client_posts_graphql_for_a_date
    posted = []
    poster = lambda do |query, variables|
      posted << [query, variables]
      { "data" => { "championshipsAgenda" => [] } }
    end
    client = GeClient.new(poster: poster)
    client.championships_agenda(Date.new(2026, 11, 11))
    client.multisport_agenda(Date.new(2026, 11, 11))

    assert_equal 2, posted.size
    assert_includes posted[0][0], "championshipsAgenda"
    assert_includes posted[0][0], "... on SoccerEvent"
    assert_includes posted[0][0], "... on MatchEventKind"
    assert_includes posted[0][0], "... on Team"
    assert_includes posted[0][0], "... on Athlete"
    assert_equal({ date: "2026-11-11" }, posted[0][1])
    assert_includes posted[1][0], "multisportTabAgenda"
    assert_includes posted[1][0], "... on SoccerEvent"
  end

  private

  def seed_day11(*ids)
    events = ids.map do |id|
      {
        ge_id: id,
        sport: "futebol",
        sport_name: "Futebol",
        title: "#{id} x Y",
        starts_at: "2026-11-11T20:00:00-03:00",
        timed: true,
        competition: "X",
        watch_on: "TV",
        note: "X"
      }
    end
    @store.replace_tv_window(events, from: Date.new(2026, 11, 11), to: Date.new(2026, 11, 17))
  end

  def recording_client(ids: {}, fail_dates: [])
    RecordingClient.new(ids: ids, fail_dates: fail_dates)
  end

  class RecordingClient
    attr_reader :futebol_dates, :multi_dates

    def initialize(ids:, fail_dates:)
      @ids = ids
      @fail_dates = fail_dates
      @futebol_dates = []
      @multi_dates = []
    end

    def championships_agenda(date)
      iso = date.iso8601
      @futebol_dates << iso
      raise GeClient::Error, "geql down" if fail?(iso)

      id = @ids[iso]&.first || "futebol-#{iso}"
      {
        "data" => {
          "championshipsAgenda" => [agenda_row("Liga", id, iso, "20:00:00", "A", "B")]
        }
      }
    end

    def multisport_agenda(date)
      iso = date.iso8601
      @multi_dates << iso
      raise GeClient::Error, "geql down" if fail?(iso)

      {
        "data" => {
          "multisportTabAgenda" => [
            {
              "sport" => { "name" => "Basquete" },
              "championshipsAgenda" => [agenda_row("NBA", "358001-#{iso}", iso, "22:00:00", "C", "D")]
            }
          ]
        }
      }
    end

    private

    def fail?(iso)
      @fail_dates == :all || Array(@fail_dates).include?(iso)
    end

    def agenda_row(champ, id, iso, hour, first, second)
      {
        "championship" => { "name" => champ },
        "now" => [],
        "past" => [],
        "future" => [
          {
            "match" => {
              "id" => id,
              "startDate" => iso,
              "startHour" => hour,
              "round" => 1,
              "firstContestant" => { "popularName" => first },
              "secondContestant" => { "popularName" => second },
              "phase" => { "name" => "Regular" },
              "liveWatchSources" => [{ "name" => "TV" }]
            }
          }
        ]
      }
    end
  end
end
