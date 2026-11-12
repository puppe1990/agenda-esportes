# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/agenda_store"
require_relative "../lib/ge_client"
require_relative "../lib/ge_sync"
require_relative "../lib/uol_client"
require_relative "support/ge_fakes"
require_relative "support/uol_fakes"

class GeSyncUolTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("agenda-sync-uol-")
    @store = AgendaStore.new(File.join(@dir, "agenda.sqlite3"))
    @now = Time.parse("2026-11-11T09:00:00-03:00")
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def test_merges_uol_broadcast_football_into_the_ge_window
    home = Faker::Sports::Football.team
    away = Faker::Sports::Football.team
    champ = Faker::Sports::Football.competition
    html = UolHtmlFixture.html(
      matches: UolHtmlFixture.match(id: 239_649, home_id: 17, away_id: 72, date: "2026-11-11", hour: "16h30"),
      teams: UolHtmlFixture.team(17, home).merge(UolHtmlFixture.team(72, away)),
      championships: { 239_649 => { "name" => champ, "phase" => "Primeira Fase" } }
    )

    result = GeSync.call(
      store: @store,
      client: EmptyGeClient.new,
      uol_client: FixtureUolClient.new(html),
      now: @now
    )

    games = @store.tv_events_on(Date.new(2026, 11, 11))
    event = games.first
    assert_equal 1, games.size
    assert_equal "uol:239649", event[:ge_id]
    assert_equal "#{home} x #{away}", event[:title]
    assert_equal "ESPN", event[:watch_on]
    assert_equal champ, event[:competition]
    assert_equal 1, result[:uol]
    assert_equal 1, result[:upserted]
  end

  def test_drops_uol_matches_outside_the_ge_window
    html = UolHtmlFixture.html(
      matches: UolHtmlFixture.match(id: 1, home_id: 1, away_id: 2, date: "2026-11-08", hour: "16h00")
                 .merge(UolHtmlFixture.match(id: 2, home_id: 1, away_id: 2, date: "2026-11-18", hour: "16h00"))
                 .merge(UolHtmlFixture.match(id: 3, home_id: 1, away_id: 2, date: "2026-11-12", hour: "21h00")),
      teams: UolHtmlFixture.team(1, "Casa").merge(UolHtmlFixture.team(2, "Fora")),
      championships: { 3 => { "name" => "Série B", "phase" => "Regular" } }
    )

    GeSync.call(store: @store, client: EmptyGeClient.new, uol_client: FixtureUolClient.new(html), now: @now)

    ids = @store.tv_events_grouped.values.flatten.map { |row| row[:ge_id] }
    assert_equal ["uol:3"], ids
  end

  def test_skips_a_uol_matchup_already_on_the_ge_grid
    html = UolHtmlFixture.html(
      matches: UolHtmlFixture.match(id: 88, home_id: 1, away_id: 2, date: "2026-11-11", hour: "20h00"),
      teams: UolHtmlFixture.team(1, "A").merge(UolHtmlFixture.team(2, "B")),
      championships: { 88 => { "name" => "Série B", "phase" => "Regular" } }
    )
    GeSync.call(
      store: @store,
      client: same_matchup_ge_client,
      uol_client: FixtureUolClient.new(html),
      now: @now
    )

    day = @store.tv_events_on(Date.new(2026, 11, 11))
    titles = day.map { |row| row[:title] }
    assert_includes titles, "A x B"
    refute_includes day.map { |row| row[:ge_id] }, "uol:88"
  end

  def test_uol_outage_keeps_previous_uol_rows_and_still_syncs_ge
    @store.replace_tv_window(
      [
        {
          ge_id: "uol:old",
          sport: "futebol",
          sport_name: "Futebol",
          title: "Velho x Jogo",
          starts_at: "2026-11-11T16:00:00-03:00",
          timed: true,
          competition: "Série B",
          watch_on: "ESPN",
          note: "Série B"
        }
      ],
      from: Date.new(2026, 11, 9),
      to: Date.new(2026, 11, 17)
    )

    result = GeSync.call(
      store: @store,
      client: EmptyGeClient.new,
      uol_client: DownUolClient.new,
      now: @now
    )

    assert result[:ok]
    assert_equal ["uol:old"], @store.tv_events_on(Date.new(2026, 11, 11)).map { |row| row[:ge_id] }
    assert_match(/uol/i, @store.sync_state[:error])
  end

  private

  def same_matchup_ge_client
    SameMatchupGeClient.new
  end

  class SameMatchupGeClient
    def championships_agenda(date)
      iso = date.iso8601
      return empty_futebol unless iso == "2026-11-11"

      {
        "data" => {
          "championshipsAgenda" => [
            {
              "championship" => { "name" => "Liga" },
              "now" => [],
              "past" => [],
              "future" => [
                {
                  "match" => {
                    "id" => "ge-keep",
                    "startDate" => iso,
                    "startHour" => "20:00:00",
                    "round" => 1,
                    "firstContestant" => { "popularName" => "A" },
                    "secondContestant" => { "popularName" => "B" },
                    "phase" => { "name" => "Regular" },
                    "liveWatchSources" => [{ "name" => "TV" }]
                  }
                }
              ]
            }
          ]
        }
      }
    end

    def multisport_agenda(_date)
      { "data" => { "multisportTabAgenda" => [] } }
    end

    def empty_futebol
      { "data" => { "championshipsAgenda" => [] } }
    end
  end
end
