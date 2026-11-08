# frozen_string_literal: true

require "time"
require_relative "sports_catalog"

class TvGrid
  FILTER_TO_SPORT = {
    "fut" => "futebol",
    "nfl" => "nfl",
    "nba" => "nba",
    "auto" => "automobilismo"
  }.freeze

  MONTH_ABBR = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze

  Event = Struct.new(:sport, :title, :starts_at, :competition, :timed, keyword_init: true) do
    def clock
      return "#{starts_at.day} #{MONTH_ABBR[starts_at.month - 1]}" unless timed

      min = starts_at.min
      return "#{starts_at.hour}h" if min.zero?

      "#{starts_at.hour}h#{min.to_s.rjust(2, '0')}"
    end
  end

  def self.game(filter, title, iso, competition, timed: true)
    sport = FILTER_TO_SPORT.fetch(filter)
    SportsCatalog.find!(sport)
    Event.new(
      sport: sport,
      title: title,
      starts_at: Time.parse(iso),
      competition: competition,
      timed: timed
    )
  end
  private_class_method :game

  ALL = [
    game("fut", "Crystal Palace x Liverpool", "2026-11-08T11:00:00-03:00", "Premier League"),
    game("fut", "RB Bragantino x Internacional", "2026-11-08T11:00:00-03:00", "Copa do Brasil feminina · semi"),
    game("nfl", "Bengals x Falcons", "2026-11-08T11:30:00-03:00", "NFL · week 9 · Madri"),
    game("fut", "Manchester United x Aston Villa", "2026-11-08T13:30:00-03:00", "Premier League"),
    game("auto", "Grande Prêmio de São Paulo", "2026-11-08T14:00:00-03:00", "Fórmula 1 · GP de São Paulo"),
    game("nfl", "Jets x Chiefs", "2026-11-08T15:00:00-03:00", "NFL · early window"),
    game("nfl", "Broncos x Panthers", "2026-11-08T15:00:00-03:00", "NFL · early window"),
    game("fut", "Athletic x Atlético-GO", "2026-11-08T16:00:00-03:00", "Série B · 37ª rodada"),
    game("fut", "Vasco x Palmeiras", "2026-11-08T17:00:00-03:00", "Copa do Brasil · volta da semi"),
    game("fut", "Atlético de Madrid x Barcelona", "2026-11-08T17:00:00-03:00", "La Liga"),
    game("nba", "76ers x Bulls", "2026-11-08T17:30:00-03:00", "NBA"),
    game("nfl", "Packers x Patriots", "2026-11-08T18:25:00-03:00", "NFL · late window"),
    game("nfl", "Raiders x 49ers", "2026-11-08T18:25:00-03:00", "NFL · late window"),
    game("fut", "Ceará x América-MG", "2026-11-08T19:15:00-03:00", "Série B · 37ª rodada"),
    game("nba", "Lakers x Pistons", "2026-11-08T20:00:00-03:00", "NBA"),
    game("nba", "Celtics x Bucks", "2026-11-08T22:00:00-03:00", "NBA"),
    game("nfl", "Buccaneers x Bears", "2026-11-08T22:20:00-03:00", "NFL · Sunday Night"),
    game("nba", "Heat x Kings · Pelicans x Clippers", "2026-11-08T23:00:00-03:00", "NBA · west"),
    game("nfl", "Bills x Vikings", "2026-11-09T22:15:00-03:00", "NFL · Monday Night"),
    game("nba", "Bucks x Knicks", "2026-11-10T19:30:00-03:00", "NBA"),
    game("nba", "Celtics x 76ers", "2026-11-10T20:00:00-03:00", "NBA"),
    game("fut", "Atlético-MG x Boca", "2026-11-21T00:00:00-03:00", "Sul-Americana · final", timed: false),
    game("auto", "Grande Prêmio de Las Vegas", "2026-11-21T00:00:00-03:00", "Fórmula 1 · Las Vegas", timed: false),
    game("fut", "Palmeiras x Estudiantes", "2026-11-28T00:00:00-03:00", "Libertadores · final", timed: false),
    game("auto", "Grande Prêmio do Catar", "2026-11-29T00:00:00-03:00", "Fórmula 1 · Catar", timed: false),
    game("fut", "Grêmio x vencedor de hoje", "2026-12-06T00:00:00-03:00", "Copa do Brasil · final", timed: false),
    game("auto", "Grande Prêmio de Abu Dhabi", "2026-12-06T00:00:00-03:00", "Fórmula 1 · Abu Dhabi", timed: false)
  ].freeze

  def self.on(day)
    date = coerce_date(day)
    ALL.select { |game| game.starts_at.to_date == date }
  end

  def self.coerce_date(value)
    return value if value.is_a?(Date) && !value.is_a?(Time)

    Date.iso8601(value.to_s)
  end
  private_class_method :coerce_date
end
