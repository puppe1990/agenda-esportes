# frozen_string_literal: true

require "json"
require_relative "../../lib/uol_client"

class EmptyUolClient
  def central_de_jogos
    "<html></html>"
  end
end

class DownUolClient
  def central_de_jogos
    raise UolClient::Error, "UOL down"
  end
end

class FixtureUolClient
  def initialize(html)
    @html = html
  end

  def central_de_jogos
    @html
  end
end

module UolHtmlFixture
  module_function

  def html(matches:, teams:, championships: {})
    payload = matches.transform_keys(&:to_s)
    core = {
      "general" => {
        "components" => {
          "FootballDailyMatches::fixture" => {
            "gender" => "m",
            "matches" => payload,
            "teams" => teams.transform_keys(&:to_s)
          }
        }
      }
    }
    state = { "football-daily-matches" => { "matches" => payload } }
    championships.each do |id, row|
      state["football-match-#{id}"] = { "id" => id, "championship" => row }
    end
    <<~HTML
      <script id="VUELAND_CORE_STATE" type="application/json">#{JSON.generate(core)}</script>
      <script id="VUELAND_STATE" type="application/json">#{JSON.generate(state)}</script>
    HTML
  end

  def match(id:, home_id:, away_id:, date:, hour: "20h00", broadcasts: [{ "name" => "ESPN" }],
            phase: "Regular", round: 1)
    {
      id.to_s => {
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

  def team(id, name)
    { id.to_s => { "id" => id, "name" => name, "slug" => name.downcase } }
  end
end
