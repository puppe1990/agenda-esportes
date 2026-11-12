# frozen_string_literal: true

require "json"
require_relative "test_helper"
require_relative "../lib/uol_parser"

class UolParserTest < Minitest::Test
  def test_parses_a_broadcast_match_from_vueland_html
    home = Faker::Sports::Football.team
    away = Faker::Sports::Football.team
    champ = Faker::Sports::Football.competition
    html = uol_html(
      match_id: 239_649,
      home_id: 17,
      away_id: 72,
      home_name: home,
      away_name: away,
      date: "2026-11-11",
      hour: "16h30",
      broadcasts: [{ "name" => "ESPN" }, { "name" => "Disney+" }],
      championship_name: champ,
      phase: "Primeira Fase",
      round: 38
    )

    events = UolParser.parse(html)
    event = events.first

    assert_equal 1, events.size
    assert_equal "uol:239649", event[:ge_id]
    assert_equal "futebol", event[:sport]
    assert_equal "Futebol", event[:sport_name]
    assert_equal "#{home} x #{away}", event[:title]
    assert_equal "2026-11-11T16:30:00-03:00", event[:starts_at]
    assert event[:timed]
    assert_equal champ, event[:competition]
    assert_equal "ESPN · Disney+", event[:watch_on]
    assert_includes event[:note], champ
    assert_includes event[:note], "Primeira Fase"
  end

  def test_skips_matches_without_broadcast
    html = uol_html(
      match_id: 1,
      broadcasts: [],
      extra_matches: [
        uol_match(id: 2, broadcasts: [{ "name" => "Premiere" }])
      ]
    )

    events = UolParser.parse(html)

    assert_equal ["uol:2"], events.map { |event| event[:ge_id] }
  end

  def test_skips_matches_without_two_team_names
    html = uol_html(match_id: 9, home_name: "", away_name: "Náutico", broadcasts: [{ "name" => "ESPN" }])

    assert_empty UolParser.parse(html)
  end

  def test_untimed_when_hour_is_blank
    html = uol_html(match_id: 4, hour: "", broadcasts: [{ "name" => "Band" }])

    event = UolParser.parse(html).first

    assert_equal "2026-11-11T00:00:00-03:00", event[:starts_at]
    refute event[:timed]
  end

  def test_empty_html_without_vueland_scripts_is_empty
    assert_empty UolParser.parse("<html><body>sem jogos</body></html>")
  end

  private

  def uol_html(match_id: 1, home_id: 10, away_id: 20, home_name: "Casa", away_name: "Fora",
               date: "2026-11-11", hour: "20h00", broadcasts: [{ "name" => "TV" }],
               championship_name: "Série B", phase: "Regular", round: 1, extra_matches: [])
    primary = uol_match(
      id: match_id, home_id: home_id, away_id: away_id, date: date, hour: hour,
      broadcasts: broadcasts, phase: phase, round: round
    )
    matches = { match_id.to_s => primary[:match] }
    extra_matches.each { |row| matches[row[:id].to_s] = row[:match] }
    teams = {
      home_id.to_s => { "id" => home_id, "name" => home_name, "slug" => "casa" },
      away_id.to_s => { "id" => away_id, "name" => away_name, "slug" => "fora" }
    }
    extra_matches.each do |row|
      teams[row[:home_id].to_s] ||= { "id" => row[:home_id], "name" => row[:home_name], "slug" => "h" }
      teams[row[:away_id].to_s] ||= { "id" => row[:away_id], "name" => row[:away_name], "slug" => "a" }
    end
    core = {
      "general" => {
        "components" => {
          "FootballDailyMatches::fixture" => {
            "gender" => "m",
            "matches" => matches,
            "teams" => teams
          }
        }
      }
    }
    state = { "football-daily-matches" => { "matches" => matches } }
    state["football-match-#{match_id}"] = {
      "id" => match_id,
      "championship" => { "id" => 22, "name" => championship_name, "phase" => phase }
    }
    extra_matches.each do |row|
      state["football-match-#{row[:id]}"] = {
        "id" => row[:id],
        "championship" => { "id" => 22, "name" => row[:championship_name], "phase" => row[:phase] }
      }
    end
    <<~HTML
      <html><head>
      <script id="VUELAND_CORE_STATE" type="application/json">#{JSON.generate(core)}</script>
      <script id="VUELAND_STATE" type="application/json">#{JSON.generate(state)}</script>
      </head></html>
    HTML
  end

  def uol_match(id:, home_id: 10, away_id: 20, date: "2026-11-11", hour: "20h00",
                broadcasts:, phase: "Regular", round: 1)
    {
      id: id,
      home_id: home_id,
      away_id: away_id,
      home_name: "Alpha",
      away_name: "Beta",
      championship_name: "Série B",
      phase: phase,
      match: {
        "championship" => { "id" => 22, "phase" => phase },
        "teams" => { "home" => home_id, "away" => away_id },
        "isoDate" => "#{date}T23:00:00.000Z",
        "date" => date,
        "hour" => hour,
        "round" => round,
        "content" => { "broadcast" => broadcasts }
      }
    }
  end
end
