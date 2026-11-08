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

  Event = Struct.new(:sport, :title, :starts_at, :competition, :timed, :where, :note, keyword_init: true) do
    def clock
      return "#{starts_at.day} #{MONTH_ABBR[starts_at.month - 1]}" unless timed

      min = starts_at.min
      return "#{starts_at.hour}h" if min.zero?

      "#{starts_at.hour}h#{min.to_s.rjust(2, '0')}"
    end
  end

  def self.game(filter, title, iso, competition, where:, note:, timed: true)
    sport = FILTER_TO_SPORT.fetch(filter)
    SportsCatalog.find!(sport)
    Event.new(
      sport: sport,
      title: title,
      starts_at: Time.parse(iso),
      competition: competition,
      timed: timed,
      where: where,
      note: note
    )
  end
  private_class_method :game

  ALL = [
    game("fut", "Crystal Palace x Liverpool", "2026-11-08T11:00:00-03:00", "Premier League",
         where: "CazéTV · Disney+",
         note: "Quatro ingleses no mesmo horário. Liverpool é o que a CazéTV coloca na frente."),
    game("fut", "RB Bragantino x Internacional", "2026-11-08T11:00:00-03:00", "Copa do Brasil feminina · semi",
         where: "sportv, Xsports, N Sports, Lance! no YouTube",
         note: "Semifinal. Paralelo ao inglês da manhã."),
    game("nfl", "Bengals x Falcons", "2026-11-08T11:30:00-03:00", "NFL · week 9 · Madri",
         where: "sportv2, ge tv · NFL Game Pass",
         note: "No Santiago Bernabéu. NFL na casa do Real Madrid. Abre a rodada americana no Brasil."),
    game("fut", "Manchester United x Aston Villa", "2026-11-08T13:30:00-03:00", "Premier League",
         where: "ESPN, Disney+, CazéTV",
         note: "Old Trafford. O inglês da tarde, antes da NFL das 15h."),
    game("auto", "Grande Prêmio de São Paulo", "2026-11-08T14:00:00-03:00", "Fórmula 1 · GP de São Paulo",
         where: "Band · Apple TV",
         note: "José Carlos Pace. 71 voltas. Largada 14h de Brasília. Antes do Vasco."),
    game("nfl", "Jets x Chiefs", "2026-11-08T15:00:00-03:00", "NFL · early window",
         where: "sportv2 · NFL Game Pass",
         note: "Arrowhead. Sete jogos neste horário; o sportv2 leva este."),
    game("nfl", "Broncos x Panthers", "2026-11-08T15:00:00-03:00", "NFL · early window",
         where: "ESPN 2, Disney+",
         note: "O outro jogo da TV brasileira neste horário. Denver 6–2."),
    game("fut", "Athletic x Atlético-GO", "2026-11-08T16:00:00-03:00", "Série B · 37ª rodada",
         where: "ESPN, Disney+",
         note: "São João del-Rei. Acesso ainda aberto na B. Antes do Vasco."),
    game("fut", "Vasco x Palmeiras", "2026-11-08T17:00:00-03:00", "Copa do Brasil · volta da semi",
         where: "Globo, ge tv · sportv, Premiere, Prime",
         note: "São Januário. Ida 1–0 Palmeiras. Sem prorrogação: empate no agregado vai a pênaltis."),
    game("fut", "Atlético de Madrid x Barcelona", "2026-11-08T17:00:00-03:00", "La Liga",
         where: "CazéTV",
         note: "Mesmo minuto do Vasco. Segundo aparelho, ou o intervalo em São Januário."),
    game("nba", "76ers x Bulls", "2026-11-08T17:30:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "United Center. Abre a noite da NBA no meio do Vasco."),
    game("nfl", "Packers x Patriots", "2026-11-08T18:25:00-03:00", "NFL · late window",
         where: "sportv2, ge tv",
         note: "Dois 5–3. O sportv2 fica neste. 49ers 6–1 saem na ESPN 2."),
    game("nfl", "Raiders x 49ers", "2026-11-08T18:25:00-03:00", "NFL · late window",
         where: "ESPN 2, Disney+",
         note: "Levi’s Stadium. O outro late game na TV brasileira. 49ers 6–1."),
    game("fut", "Ceará x América-MG", "2026-11-08T19:15:00-03:00", "Série B · 37ª rodada",
         where: "Xsports, SportyNet, Disney+",
         note: "Castelão. Depois do Vasco. Acesso ainda aberto na B."),
    game("nba", "Lakers x Pistons", "2026-11-08T20:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Detroit. Lakers 8–2, Pistons 6–2. Luka Dončić contra Cade Cunningham."),
    game("nba", "Celtics x Bucks", "2026-11-08T22:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Milwaukee. Boston 7–2, Bucks 1–8. Choque com o Sunday Night Football."),
    game("nfl", "Buccaneers x Bears", "2026-11-08T22:20:00-03:00", "NFL · Sunday Night",
         where: "sportv2 · NFL Game Pass",
         note: "Chicago 6–2 em casa. O jogo da noite na TV."),
    game("nba", "Heat x Kings · Pelicans x Clippers", "2026-11-08T23:00:00-03:00", "NBA · west",
         where: "NBA League Pass",
         note: "Dois jogos da costa oeste no mesmo minuto. Madrugada."),
    game("nfl", "Bills x Vikings", "2026-11-09T22:15:00-03:00", "NFL · Monday Night",
         where: "ESPN, Disney+ Premium · NFL Game Pass",
         note: "Dois times 6–1. Josh Allen contra a defesa de Minnesota. O melhor jogo da rodada."),
    game("nba", "Bucks x Knicks", "2026-11-10T19:30:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Madison Square Garden. Antes do Celtics–Sixers."),
    game("nba", "Celtics x 76ers", "2026-11-10T20:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Philadelphia. Boston 7–2 visita os Sixers 8–2. O leste no começo da temporada."),
    game("fut", "Atlético-MG x Boca", "2026-11-21T00:00:00-03:00", "Sul-Americana · final",
         where: "SBT · Disney+ · Paramount+",
         note: "Metropolitano, Barranquilla. Final. 20h de Brasília.",
         timed: false),
    game("auto", "Grande Prêmio de Las Vegas", "2026-11-21T00:00:00-03:00", "Fórmula 1 · Las Vegas",
         where: "Band · Apple TV",
         note: "Street Circuit. Largada à noite no Strip; no Brasil vira madrugada do dia 22.",
         timed: false),
    game("fut", "Palmeiras x Estudiantes", "2026-11-28T00:00:00-03:00", "Libertadores · final",
         where: "Globo · ESPN · Disney+",
         note: "Centenário, Montevidéu, 17h. Final da Libertadores.",
         timed: false),
    game("auto", "Grande Prêmio do Catar", "2026-11-29T00:00:00-03:00", "Fórmula 1 · Catar",
         where: "Band · Apple TV",
         note: "Losail. Penúltima prova do mundial.",
         timed: false),
    game("fut", "Grêmio x vencedor de hoje", "2026-12-06T00:00:00-03:00", "Copa do Brasil · final",
         where: "Globo · Premiere",
         note: "Jogo único no Mané Garrincha. O adversário sai de São Januário.",
         timed: false),
    game("auto", "Grande Prêmio de Abu Dhabi", "2026-12-06T00:00:00-03:00", "Fórmula 1 · Abu Dhabi",
         where: "Band · Apple TV",
         note: "Yas Marina. Encerramento da temporada, mesmo domingo da final da Copa do Brasil.",
         timed: false)
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
