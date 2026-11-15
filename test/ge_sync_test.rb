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

    dates = (Date.new(2026, 11, 9)..Date.new(2026, 11, 17)).to_a
    assert_equal dates, client.dates
    assert_equal dates, client.dates
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

    dates = (Date.new(2026, 11, 9)..Date.new(2026, 11, 15)).to_a
    assert_equal dates, client.dates
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

  def test_due_is_false_right_after_a_successful_sync
    @store.record_sync!(synced_at: @now, event_count: 3)

    refute GeSync.due?(@store, now: @now + 60)
  end

  def test_due_is_true_when_the_snapshot_passed_twenty_hours
    @store.record_sync!(synced_at: @now - (21 * 3600), event_count: 3)

    assert GeSync.due?(@store, now: @now)
  end

  def test_due_waits_ten_minutes_before_retrying_a_failure
    @store.record_sync!(synced_at: @now, event_count: 3, error: "geql down")

    refute GeSync.due?(@store, now: @now + 60)
    assert GeSync.due?(@store, now: @now + (11 * 60))
  end

  def test_refresh_async_returns_false_while_a_run_is_in_flight
    gate = Queue.new
    client = Object.new
    client.define_singleton_method(:agenda_range) do |_dates|
      gate.pop
      {}
    end

    assert GeSync.refresh_async(store: @store, client: client, uol_client: nil)
    refute GeSync.refresh_async(store: @store, client: client, uol_client: nil)
  ensure
    gate&.push(:go)
    sleep 0.05
    GeSync.reset_running!
  end

  def test_client_posts_one_document_with_both_roots
    posted = []
    poster = lambda do |query, variables|
      posted << [query, variables]
      { "data" => {} }
    end
    client = GeClient.new(poster: poster)
    client.agenda_range([Date.new(2026, 11, 11)])

    assert_equal 1, posted.size
    query = posted[0][0]
    assert_includes query, "championshipsAgenda"
    assert_includes query, "multisportTabAgenda"
    assert_includes query, "... on SoccerEvent"
    assert_includes query, "... on MatchEventKind"
    assert_includes query, "... on Team"
    assert_includes query, "... on Athlete"
    assert_equal({}, posted[0][1])
  end

  # Regression: geql answers a POST from a PUBLIC-scoped HTTP cache. While
  # the two roots were separate documents they collided and one root came
  # back holding the other's rows, dropping half the window in silence.
  def test_one_document_per_window_prevents_cross_root_cache_collisions
    queries = []
    poster = lambda do |query, _variables|
      queries << query
      {
        "data" => {
          "c0" => [{ "championship" => { "name" => "Liga" }, "now" => [], "past" => [], "future" => [] }],
          "m0" => [{ "sport" => { "name" => "Basquete" }, "championshipsAgenda" => [] }]
        }
      }
    end
    slices = GeClient.new(poster: poster).agenda_range([Date.new(2026, 11, 11)])

    assert_equal 1, queries.size
    assert_equal 1, slices[Date.new(2026, 11, 11)].dig("championshipsAgenda", "data", "championshipsAgenda").size
    assert_equal 1, slices[Date.new(2026, 11, 11)].dig("multisportTabAgenda", "data", "multisportTabAgenda").size
  end

  def test_window_is_fetched_in_a_single_request
    client = recording_client
    GeSync.call(store: @store, client: client, now: @now)

    assert_equal 1, client.calls
    assert_equal (Date.new(2026, 11, 9)..Date.new(2026, 11, 17)).to_a, client.dates
  end

  def test_a_blank_day_in_the_batch_keeps_its_rows
    seed_day11("old-11")
    client = recording_client(blank_dates: ["2026-11-11"])
    GeSync.call(store: @store, client: client, now: @now)

    assert_equal ["old-11"], @store.tv_events_on(Date.new(2026, 11, 11)).map { |row| row[:ge_id] }
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

  def recording_client(ids: {}, fail_dates: [], blank_dates: [])
    RecordingClient.new(ids: ids, fail_dates: fail_dates, blank_dates: blank_dates)
  end

  class RecordingClient
    attr_reader :dates, :calls

    def initialize(ids:, fail_dates:, blank_dates: [])
      @ids = ids
      @fail_dates = fail_dates
      @blank_dates = Array(blank_dates)
      @dates = []
      @calls = 0
    end

    def agenda_range(dates)
      @calls += 1
      raise GeClient::Error, "geql down" if @fail_dates == :all

      @dates.concat(dates)
      dates.to_h { |date| [date, slice(date)] }
    end

    private

    def slice(date)
      iso = date.iso8601
      return nil if @blank_dates.include?(iso) || fail?(iso)

      id = @ids[iso]&.first || "futebol-#{iso}"
      {
        "championshipsAgenda" => {
          "data" => { "championshipsAgenda" => [agenda_row("Liga", id, iso, "20:00:00", "A", "B")] }
        },
        "multisportTabAgenda" => {
          "data" => {
            "multisportTabAgenda" => [
              {
                "sport" => { "name" => "Basquete" },
                "championshipsAgenda" => [agenda_row("NBA", "358001-#{iso}", iso, "22:00:00", "C", "D")]
              }
            ]
          }
        }
      }
    end

    def fail?(iso)
      Array(@fail_dates).include?(iso)
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
