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
    game("nba", "Wizards x Pistons", "2026-11-09T21:00:00-03:00", "NBA",
         where: "ESPN 2, Disney+ · NBA League Pass",
         note: "Little Caesars. O jogo da TV nesta segunda. Pistons 6–3, também em back-to-back depois do Lakers."),
    game("nba", "Lakers x Hawks", "2026-11-09T21:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "State Farm Arena. Lakers 9–2, segundo jogo em noites seguidas. Luka Dončić em Atlanta."),
    game("nba", "Grizzlies x Raptors", "2026-11-09T21:30:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Scotiabank Arena. Grizzlies 6–3, invictos fora (4–0). Antes do Monday Night."),
    game("nfl", "Bills x Vikings", "2026-11-09T22:15:00-03:00", "NFL · Monday Night",
         where: "ESPN 2, Disney+ Premium · NFL Game Pass",
         note: "U.S. Bank Stadium. Dois times 6–1. Josh Allen contra a defesa de Minnesota. Wentz no lugar de Murray."),
    game("nba", "Nuggets x Rockets", "2026-11-09T22:30:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Toyota Center. Oeste: Rockets 7–3 recebem o Denver 5–3. Choque com o Monday Night."),
    game("nba", "Spurs x Suns", "2026-11-09T23:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Phoenix. Spurs 8–2, invictos fora. Fecha a noite no League Pass."),
    game("nba", "Bucks x Knicks", "2026-11-10T21:30:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Madison Square Garden. Bucks 1–9. Antes do Celtics–Sixers no Prime."),
    game("nba", "Celtics x 76ers", "2026-11-10T22:00:00-03:00", "NBA",
         where: "Prime · NBA League Pass",
         note: "Philadelphia. Boston 8–2 visita os Sixers 9–2. O jogo da TV nesta terça."),
    game("nba", "Thunder x Blazers", "2026-11-11T01:00:00-03:00", "NBA",
         where: "Prime · NBA League Pass",
         note: "Moda Center. Thunder 8–2. Começou terça nos EUA; 1h de Brasília."),
    game("nba", "Cavaliers x Knicks", "2026-11-11T21:00:00-03:00", "NBA",
         where: "ESPN 2, Disney+ · NBA League Pass",
         note: "Madison Square Garden. Cavs 5–5, Knicks 5–4. O jogo da ESPN nesta quarta."),
    game("nba", "Lakers x Bucks", "2026-11-11T22:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Fiserv Forum. Lakers 9–2 contra os Bucks 1–9. Luka Dončić em Milwaukee."),
    game("nba", "Warriors x Rockets", "2026-11-11T23:30:00-03:00", "NBA",
         where: "ESPN 2, Disney+ · NBA League Pass",
         note: "Toyota Center. Warriors 7–3, Rockets 7–3. Oeste na ESPN."),
    game("nba", "Raptors x 76ers", "2026-11-12T21:00:00-03:00", "NBA",
         where: "Prime · NBA League Pass",
         note: "Philadelphia. Sixers 9–2 recebem Toronto. Antes do Thursday Night."),
    game("nba", "Mavericks x Timberwolves", "2026-11-12T22:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Target Center. Wolves 8–3 recebem Dallas 6–4. Choque com o TNF."),
    game("nfl", "Commanders x Giants", "2026-11-12T22:15:00-03:00", "NFL · Thursday Night",
         where: "sportv2, ge tv · NFL Game Pass",
         note: "MetLife. Giants 5–2–1 recebem Washington 2–5–1. O Thursday Night."),
    game("nba", "Knicks x Pacers", "2026-11-13T21:00:00-03:00", "NBA",
         where: "Prime · NBA League Pass",
         note: "Gainbridge Fieldhouse. Knicks 5–4 visitam os Pacers 3–7. Prime nesta sexta."),
    game("nba", "Warriors x Spurs", "2026-11-13T23:30:00-03:00", "NBA",
         where: "Prime · NBA League Pass",
         note: "San Antonio. Spurs 8–2. Fecha a sexta no Prime."),
    game("fut", "Criciúma x Novorizontino", "2026-11-14T16:30:00-03:00", "Série B · 38ª rodada",
         where: "Disney+ Premium · Xsports",
         note: "Heriberto Hülse. Última rodada. Novorizontino líder, 70 pontos; vitória dá o título."),
    game("fut", "Fortaleza x Vila Nova", "2026-11-14T16:30:00-03:00", "Série B · 38ª rodada",
         where: "Disney+ Premium · Xsports, SportyNet",
         note: "Castelão. Vila Nova já nos playoffs. Fortaleza 62 também classificado."),
    game("fut", "Juventude x Botafogo-SP", "2026-11-14T16:30:00-03:00", "Série B · 38ª rodada",
         where: "Disney+ Premium · Xsports, SportyNet",
         note: "Alfredo Jaconi. Juventude 68 pontos, ainda briga o título com o líder."),
    game("nba", "Pistons x Heat", "2026-11-14T22:00:00-03:00", "NBA",
         where: "ESPN 2, Disney+ · NBA League Pass",
         note: "Kaseya Center. Pistons 6–3 visitam o Heat. O jogo da TV no sábado."),
    game("nfl", "Patriots x Lions", "2026-11-15T11:30:00-03:00", "NFL · week 10 · Munique",
         where: "sportv2, ge tv · NFL Game Pass",
         note: "Allianz Arena. Lions 6–2 mandante em Munique. Abre a rodada no Brasil."),
    game("nfl", "Vikings x Packers", "2026-11-15T15:00:00-03:00", "NFL · early window",
         where: "sportv2 · NFL Game Pass",
         note: "Lambeau. Vikings 6–1, Packers 6–3. O sportv2 fica neste."),
    game("nfl", "Bills x Jets", "2026-11-15T15:00:00-03:00", "NFL · early window",
         where: "ESPN 2, Disney+",
         note: "MetLife. Bills 6–1 contra os Jets 2–7. O outro da TV às 15h."),
    game("nba", "Lakers x Suns", "2026-11-15T18:00:00-03:00", "NBA",
         where: "NBA League Pass",
         note: "Phoenix. Lakers 9–2. Antes do 49ers–Cowboys."),
    game("nfl", "49ers x Cowboys", "2026-11-15T18:25:00-03:00", "NFL · late window",
         where: "sportv2, ge tv",
         note: "AT&T Stadium. 49ers 7–1 visitam Dallas. O late game na TV."),
    game("nba", "Mavericks x Celtics", "2026-11-15T20:00:00-03:00", "NBA",
         where: "Prime · NBA League Pass",
         note: "TD Garden. Dallas 6–4 em Boston 8–2. O Prime neste domingo."),
    game("nfl", "Steelers x Bengals", "2026-11-15T22:20:00-03:00", "NFL · Sunday Night",
         where: "sportv2 · NFL Game Pass",
         note: "Paycor Stadium. Dois times 6–2. O jogo da noite na TV."),
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
