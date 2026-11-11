# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/ge_parser"

class GeParserTest < Minitest::Test
  def test_parses_a_futebol_match_with_watch_sources
    home = Faker::Sports::Football.team
    away = Faker::Sports::Football.team
    champ = Faker::Sports::Football.competition
    payload = {
      "data" => {
        "championshipsAgenda" => [
          {
            "championship" => { "name" => champ, "url" => "https://ge.globo.com/x" },
            "now" => [],
            "past" => [],
            "future" => [
              match_event(
                id: 34_9105,
                start_date: "2026-11-11",
                start_hour: "19:00:00",
                round: 38,
                phase: "Fase única",
                first: home,
                second: away,
                sources: [{ "name" => "Disney+" }, { "name" => "Premiere" }]
              )
            ]
          }
        ]
      }
    }

    events = GeParser.parse(payload)
    event = events.first

    assert_equal 1, events.size
    assert_equal "349105", event[:ge_id]
    assert_equal "futebol", event[:sport]
    assert_equal "Futebol", event[:sport_name]
    assert_equal "#{home} x #{away}", event[:title]
    assert_equal "2026-11-11T19:00:00-03:00", event[:starts_at]
    assert event[:timed]
    assert_equal champ, event[:competition]
    assert_equal "Disney+ · Premiere", event[:watch_on]
    assert_includes event[:note], champ
    assert_match(/38|Fase única/, event[:note])
  end

  def test_nba_and_nbb_share_the_basquete_slug
    nba_home = Faker::Sports::Basketball.team
    nba_away = Faker::Sports::Basketball.team
    nbb_home = Faker::Team.name
    nbb_away = Faker::Team.name
    payload = {
      "data" => {
        "multisportTabAgenda" => [
          {
            "sport" => { "code" => "BSK", "name" => "Basquete" },
            "championshipsAgenda" => [
              {
                "championship" => { "name" => "NBA", "url" => "https://ge.globo.com/nba" },
                "now" => [],
                "past" => [],
                "future" => [
                  match_event(id: 358_001, start_date: "2026-11-11", start_hour: "22:00:00",
                              round: 20, phase: "Temporada regular", first: nba_home, second: nba_away,
                              sources: [{ "name" => "NBA League Pass" }])
                ]
              },
              {
                "championship" => { "name" => "NBB", "url" => "https://ge.globo.com/nbb" },
                "now" => [],
                "past" => [],
                "future" => [
                  match_event(id: 358_002, start_date: "2026-11-11", start_hour: "19:30:00",
                              round: 7, phase: "Regular", first: nbb_home, second: nbb_away,
                              sources: nil)
                ]
              }
            ]
          }
        ]
      }
    }

    events = GeParser.parse(payload)

    assert_equal 2, events.size
    assert(events.all? { |event| event[:sport] == "basquete" })
    assert(events.all? { |event| event[:sport_name] == "Basquete" })
    nba = events.find { |event| event[:competition] == "NBA" }
    nbb = events.find { |event| event[:competition] == "NBB" }
    assert_equal "NBA League Pass", nba[:watch_on]
    assert_nil nbb[:watch_on]
    assert_equal "2026-11-11T19:30:00-03:00", nbb[:starts_at]
  end

  def test_skips_events_without_two_contestants
    payload = {
      "data" => {
        "multisportTabAgenda" => [
          {
            "sport" => { "name" => "Atletismo" },
            "championshipsAgenda" => [
              {
                "championship" => { "name" => "Diamond League" },
                "future" => [
                  { "match" => { "id" => 1, "startDate" => "2026-11-11", "startHour" => "10:00:00" } }
                ],
                "now" => [],
                "past" => []
              }
            ]
          }
        ]
      }
    }

    assert_empty GeParser.parse(payload)
  end

  def test_untimed_event_when_hour_is_missing
    payload = {
      "data" => {
        "championshipsAgenda" => [
          {
            "championship" => { "name" => "Fórmula 1" },
            "future" => [
              match_event(
                id: 99,
                start_date: "2026-12-06",
                start_hour: nil,
                round: nil,
                phase: "Abu Dhabi",
                first: "Verstappen",
                second: "Norris",
                sources: [{ "name" => "Band" }]
              )
            ],
            "now" => [],
            "past" => []
          }
        ]
      }
    }

    event = GeParser.parse(payload).first

    assert_equal "2026-12-06T00:00:00-03:00", event[:starts_at]
    refute event[:timed]
  end

  private

  def match_event(id:, start_date:, start_hour:, round:, phase:, first:, second:, sources:)
    {
      "__typename" => "MatchEventKind",
      "match" => {
        "id" => id,
        "startDate" => start_date,
        "startHour" => start_hour,
        "round" => round,
        "firstContestant" => { "popularName" => first },
        "secondContestant" => { "popularName" => second },
        "phase" => { "name" => phase },
        "liveWatchSources" => sources
      }
    }
  end
end
