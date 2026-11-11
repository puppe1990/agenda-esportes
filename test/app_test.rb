# frozen_string_literal: true

require_relative "test_helper"
require "rack/test"
require "json"

ENV["DATABASE_PATH"] = File.join(Dir.mktmpdir("agenda-esportes-app-"), "agenda.sqlite3")

require_relative "../app"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    AgendaEsportes::App
  end

  def setup
    path = ENV.fetch("DATABASE_PATH")
    FileUtils.rm_f(path)
    AgendaEsportes::App.store = AgendaStore.new(path)
    AgendaEsportes::App.ge_client = nil if AgendaEsportes::App.respond_to?(:ge_client=)
  end

  def test_home_lists_automobilismo_instead_of_corrida
    seed_tv(
      sport: "automobilismo",
      sport_name: "Automobilismo",
      title: Faker::Vehicle.make_and_model
    )
    get "/?dia=2026-11-08"

    assert last_response.ok?
    assert_includes last_response.body, "Automobilismo"
    refute_includes last_response.body, "Corrida"
    refute_match(/>corrida</i, last_response.body)
  end

  def test_home_renders_game_cards_that_post_the_match_into_the_agenda
    title = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    seed_tv(title: title, starts_at: "2026-11-08T17:00:00-03:00")
    get "/?dia=2026-11-08"

    assert_includes last_response.body, "agendinha"
    assert_includes last_response.body, 'class="game-card"'
    assert_includes last_response.body, title
    assert_includes last_response.body, 'name="title"'
    assert_includes last_response.body, %(value="#{title}")
    assert_includes last_response.body, 'value="futebol"'
    refute_includes last_response.body, "<select"
    refute_includes last_response.body, "Colocar na agenda"
    refute_includes last_response.body, 'value="corrida"'
    refute_includes last_response.body, 'class="sport-card"'
    assert_includes last_response.body, 'name="kicks_at"'
    assert_includes last_response.body, 'value="17h"'
    assert_includes last_response.body, 'name="note"'
    assert_includes last_response.body, 'name="watch"'
  end

  def test_home_game_cards_show_where_to_watch_and_a_game_note
    seed_tv(
      title: "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}",
      watch_on: "Globo · CazéTV",
      note: "Ida 1–0. Sem prorrogação: empate no agregado vai a pênaltis."
    )
    get "/?dia=2026-11-08"

    assert_includes last_response.body, 'class="game-card-where"'
    assert_includes last_response.body, 'class="game-card-note"'
    assert_includes last_response.body, "Globo"
    assert_match(/pênaltis|penaltis/i, last_response.body)
    assert_includes last_response.body, "CazéTV"
  end

  def test_monday_game_card_shows_espn_and_standings
    home = Faker::Sports::Basketball.team
    away = Faker::Sports::Basketball.team
    title = "#{home} x #{away}"
    seed_tv(
      sport: "basquete",
      sport_name: "Basquete",
      title: title,
      starts_at: "2026-11-09T21:00:00-03:00",
      watch_on: "ESPN",
      note: "NBA · 6–1"
    )
    get "/?dia=2026-11-09"

    assert_includes last_response.body, title
    assert_includes last_response.body, "ESPN"
    assert_match(/6.?1/, last_response.body)
    assert_includes last_response.body, 'data-s="basquete"'
    refute_includes last_response.body, 'class="sport-card"'
  end

  def test_home_renders_sport_cards_when_the_day_has_no_tv_games
    seed_tv(
      { sport: "futebol", sport_name: "Futebol" },
      { sport: "basquete", sport_name: "Basquete", starts_at: "2026-11-09T21:00:00-03:00" }
    )
    get "/?dia=2026-11-17"

    assert_includes last_response.body, 'class="sport-card"'
    assert_includes last_response.body, 'value="futebol"'
    assert_includes last_response.body, 'value="basquete"'
    refute_includes last_response.body, 'class="game-card"'
    refute_includes last_response.body, "<select"
    refute_includes last_response.body, 'value="corrida"'
    assert_equal 2, last_response.body.scan(/class="sport-card"/).size
  end

  def test_post_places_the_selected_sport_on_the_chosen_day
    title = Faker::Vehicle.make_and_model

    post "/agenda", {
      sport: "automobilismo",
      day: "2026-11-08",
      title: title,
      authenticity_token: csrf_token
    }

    assert_equal 302, last_response.status
    follow_redirect!

    assert_includes last_response.body, title
    assert_includes last_response.body, "Automobilismo"

    stored = AgendaEsportes::App.store.items_on(Date.new(2026, 11, 8))
    assert_equal 1, stored.size
    assert_equal "automobilismo", stored.first.sport
    assert_equal title, stored.first.title
  end

  def test_post_game_stores_the_match_title_and_lists_sport_plus_game
    title = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    post "/agenda", {
      sport: "futebol",
      day: "2026-11-08",
      title: title,
      authenticity_token: csrf_token
    }

    assert_equal 302, last_response.status
    follow_redirect!

    stored = AgendaEsportes::App.store.items_on(Date.new(2026, 11, 8))
    assert_equal 1, stored.size
    assert_equal "futebol", stored.first.sport
    assert_equal title, stored.first.title
    assert_includes last_response.body, title
    assert_includes last_response.body, "Futebol"
    refute_match(
      %r{<h3><a href="/agenda/#{stored.first.id}">Futebol</a></h3>},
      last_response.body
    )
  end

  def test_post_game_keeps_kickoff_and_note_on_the_agenda
    title = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    note = "São Januário. Ida 1–0. Sem prorrogação: empate no agregado vai a pênaltis."

    post "/agenda", {
      sport: "futebol",
      day: "2026-11-08",
      title: title,
      kicks_at: "17h",
      note: note,
      watch: "Globo, ge tv · sportv, Premiere, Prime",
      authenticity_token: csrf_token
    }

    assert_equal 302, last_response.status
    follow_redirect!

    stored = AgendaEsportes::App.store.items_on(Date.new(2026, 11, 8)).first
    assert_equal "17h", stored.kicks_at
    assert_equal note, stored.note
    assert_equal "Globo, ge tv · sportv, Premiere, Prime", stored.watch_on
    assert_match(%r{<time datetime="2026-11-08">17h</time>}, last_response.body)
    assert_includes last_response.body, 'class="meta"'
    assert_match(/pênaltis|penaltis/i, last_response.body)

    get "/agenda/#{stored.id}"
    assert last_response.ok?
    assert_includes last_response.body, "17h"
    assert_includes last_response.body, "Globo"
    assert_match(/pênaltis|penaltis/i, last_response.body)

    get "/agenda"
    assert_match(%r{<time datetime="2026-11-08">17h</time>}, last_response.body)
    assert_match(/pênaltis|penaltis/i, last_response.body)
  end

  def test_home_lists_saved_items_in_kickoff_order
    day = Date.new(2026, 11, 8)
    AgendaEsportes::App.store.add(sport: "nfl", starts_at: day, title: Faker::Team.name, kicks_at: "22h20")
    AgendaEsportes::App.store.add(sport: "futebol", starts_at: day, title: Faker::Sports::Football.team, kicks_at: "11h")
    AgendaEsportes::App.store.add(sport: "nba", starts_at: day, title: Faker::Team.name, kicks_at: "17h30")

    get "/?dia=2026-11-08"

    clocks = last_response.body.scan(%r{<time datetime="2026-11-08">([^<]+)</time>}).flatten
    assert_equal %w[11h 17h30 22h20], clocks
  end

  def test_saved_item_always_shows_sport_and_match
    title = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    item = AgendaEsportes::App.store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: title
    )

    get "/?dia=2026-11-08"

    assert_includes last_response.body, "Futebol"
    assert_includes last_response.body, title
    assert_includes last_response.body, "<p class=\"comp\">Futebol</p>"
    assert_includes last_response.body, "/agenda/#{item.id}"
  end

  def test_post_without_title_uses_the_sport_name
    post "/agenda", {
      sport: "nba",
      day: "2026-11-10",
      authenticity_token: csrf_token
    }

    assert_equal 302, last_response.status
    follow_redirect!

    stored = AgendaEsportes::App.store.items_on(Date.new(2026, 11, 10))
    assert_equal 1, stored.size
    assert_equal "nba", stored.first.sport
    assert_equal "NBA", stored.first.title
    assert_includes last_response.body, "NBA"
  end

  def test_post_corrida_is_rejected
    post "/agenda", {
      sport: "corrida",
      day: "2026-11-08",
      title: Faker::Lorem.word,
      authenticity_token: csrf_token
    }

    assert_equal 422, last_response.status
    assert_empty AgendaEsportes::App.store.all
  end

  def test_home_is_the_system_without_editorial_copy
    football = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    gp = Faker::Vehicle.make_and_model
    seed_tv(
      { title: football },
      { sport: "automobilismo", sport_name: "Automobilismo", title: gp, starts_at: "2026-11-08T14:00:00-03:00" }
    )
    get "/?dia=2026-11-08"

    assert_includes last_response.body, 'class="cal"'
    assert_includes last_response.body, 'class="game-card"'
    assert_includes last_response.body, football
    assert_includes last_response.body, gp
    refute_includes last_response.body, "Domingo lotado"
    refute_includes last_response.body, "A grade que sobrou"
    refute_includes last_response.body, "Três esportes, um relógio"
    refute_includes last_response.body, "Las Vegas, finais no continente"
    refute_includes last_response.body, "Interlagos"
    refute_includes last_response.body, "Clica no jogo. Entra no dia."
    refute_includes last_response.body, "coloca no dia"
    refute_includes last_response.body, "/// 05 · fonte"
  end

  def test_agenda_index_is_the_list_without_editorial_copy
    title = Faker::Team.name
    AgendaEsportes::App.store.add(
      sport: "nba",
      starts_at: Date.new(2026, 11, 12),
      title: title
    )

    get "/agenda"

    assert last_response.ok?
    assert_includes last_response.body, title
    refute_includes last_response.body, "O que você colocou."
    refute_includes last_response.body, "SQLite"
    refute_includes last_response.body, "grade da TV"
  end

  def test_agenda_index_lists_saved_items
    title = Faker::Team.name
    AgendaEsportes::App.store.add(
      sport: "nba",
      starts_at: Date.new(2026, 11, 12),
      title: title
    )

    get "/agenda"

    assert last_response.ok?
    assert_includes last_response.body, title
    assert_includes last_response.body, "NBA"
    assert_includes last_response.body, "/agenda/"
  end

  def test_agenda_show_renders_the_item
    title = Faker::Vehicle.make_and_model
    item = AgendaEsportes::App.store.add(
      sport: "automobilismo",
      starts_at: Date.new(2026, 11, 21),
      title: title
    )

    get "/agenda/#{item.id}"

    assert last_response.ok?
    assert_includes last_response.body, title
    assert_includes last_response.body, "Automobilismo"
    assert_includes last_response.body, "/agenda/#{item.id}/edit"
  end

  def test_agenda_show_unknown_is_404
    get "/agenda/9999"

    assert_equal 404, last_response.status
    assert_match(/não encontrado/i, last_response.body)
    assert_includes last_response.body, "Esse item não está na agenda."
  end

  def test_agenda_edit_renders_the_form
    item = AgendaEsportes::App.store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: Faker::Sports::Football.team
    )

    get "/agenda/#{item.id}/edit"

    assert last_response.ok?
    assert_includes last_response.body, 'name="sport"'
    assert_includes last_response.body, 'value="automobilismo"'
    assert_includes last_response.body, 'name="day"'
    assert_includes last_response.body, 'name="title"'
    refute_includes last_response.body, "<select"
    refute_includes last_response.body, 'value="corrida"'
  end

  def test_patch_updates_the_item
    item = AgendaEsportes::App.store.add(
      sport: "nfl",
      starts_at: Date.new(2026, 11, 9),
      title: Faker::Team.name
    )
    title = Faker::Team.name

    patch "/agenda/#{item.id}", {
      sport: "nba",
      day: "2026-11-20",
      title: title,
      authenticity_token: csrf_token
    }

    assert_equal 302, last_response.status
    follow_redirect!

    stored = AgendaEsportes::App.store.find(item.id)
    assert_equal "nba", stored.sport
    assert_equal title, stored.title
    assert_equal Date.new(2026, 11, 20), stored.starts_on
    assert_includes last_response.body, title
  end

  def test_delete_removes_the_item
    item = AgendaEsportes::App.store.add(
      sport: "nba",
      starts_at: Date.new(2026, 11, 10),
      title: Faker::Team.name
    )

    delete "/agenda/#{item.id}", { authenticity_token: csrf_token }

    assert_equal 302, last_response.status
    assert_nil AgendaEsportes::App.store.find(item.id)
  end

  def test_patch_corrida_is_rejected
    item = AgendaEsportes::App.store.add(
      sport: "nba",
      starts_at: Date.new(2026, 11, 10),
      title: Faker::Team.name
    )

    patch "/agenda/#{item.id}", {
      sport: "corrida",
      day: "2026-11-10",
      title: Faker::Lorem.word,
      authenticity_token: csrf_token
    }

    assert_equal 422, last_response.status
    assert_equal "nba", AgendaEsportes::App.store.find(item.id).sport
  end

  def test_delete_unknown_is_404
    delete "/agenda/9999", { authenticity_token: csrf_token }

    assert_equal 404, last_response.status
  end

  def test_saved_match_without_details_fills_from_the_tv_grid
    title = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    seed_tv(
      title: title,
      starts_at: "2026-11-08T17:00:00-03:00",
      watch_on: "Globo",
      note: "Ida 1–0. Vai a pênaltis."
    )
    AgendaEsportes::App.store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: title
    )

    get "/?dia=2026-11-08"

    stored = AgendaEsportes::App.store.items_on(Date.new(2026, 11, 8)).first
    assert_equal "17h", stored.kicks_at
    assert_match(/pênaltis|penaltis/i, stored.note)
    assert_includes stored.watch_on, "Globo"
    assert_match(%r{<time datetime="2026-11-08">17h</time>}, last_response.body)
  end

  def test_home_item_links_to_show_edit_and_delete
    item = AgendaEsportes::App.store.add(
      sport: "nfl",
      starts_at: Date.new(2026, 11, 8),
      title: Faker::Team.name
    )

    get "/?dia=2026-11-08"

    assert_includes last_response.body, "/agenda/#{item.id}"
    assert_includes last_response.body, "/agenda/#{item.id}/edit"
    assert_includes last_response.body, 'value="delete"'
  end

  def test_selected_calendar_cell_keeps_a_height_cap
    css = File.read(File.expand_path("../public/app.css", __dir__))
    rules = css.scan(/\.cal-cell\.is-on\{[^}]+\}/)
    refute_empty rules
    rules.each do |rule|
      refute_match(/max-height:\s*none/, rule)
    end
  end

  def test_home_month_grid_shows_games_from_other_days_as_chips
    monday = "#{Faker::Team.name} x #{Faker::Team.name}"
    seed_tv(
      { title: "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}" },
      {
        sport: "nfl",
        sport_name: "NFL",
        title: monday,
        starts_at: "2026-11-09T22:00:00-03:00"
      }
    )
    get "/?dia=2026-11-08"

    assert_includes last_response.body, 'class="cal-event"'
    assert_includes last_response.body, monday
    assert_match(
      %r{class="cal-event"[^>]*data-s="nfl"[\s\S]*?name="day" value="2026-11-09"[\s\S]*?name="title" value="#{Regexp.escape(monday)}"},
      last_response.body
    )
    refute_includes last_response.body, "<select"
    refute_includes last_response.body, "Colocar na agenda"
  end

  def test_saved_tv_game_becomes_a_saved_chip_on_the_calendar
    title = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    seed_tv(title: title)
    item = AgendaEsportes::App.store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: title,
      kicks_at: "17h"
    )

    get "/?dia=2026-11-08"

    assert_match(
      %r{<a class="cal-event is-saved" data-s="futebol" href="/agenda/#{item.id}">},
      last_response.body
    )
    cal_forms = last_response.body.scan(%r{<form method="post" action="/agenda" class="cal-event".*?</form>}m)
    refute cal_forms.any? { |form| form.include?(%(value="#{title}")) }
  end

  def test_day_cards_skip_games_already_on_the_agenda
    saved = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    open_game = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    seed_tv({ title: saved }, { title: open_game, starts_at: "2026-11-08T16:00:00-03:00" })
    AgendaEsportes::App.store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: saved,
      kicks_at: "17h"
    )

    get "/?dia=2026-11-08"

    game_cards = last_response.body.scan(%r{<form method="post" action="/agenda" class="game-card".*?</form>}m)
    refute game_cards.any? { |form| form.include?(%(value="#{saved}")) }
    assert game_cards.any? { |form| form.include?(%(value="#{open_game}")) }
  end

  def test_home_opens_the_day_from_dia_mes_ano_query
    sunday = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"
    monday = "#{Faker::Team.name} x #{Faker::Team.name}"
    seed_tv(
      { title: sunday },
      { sport: "nfl", sport_name: "NFL", title: monday, starts_at: "2026-11-09T22:00:00-03:00" }
    )
    get "/?dia=8&mes=11&ano=2026"

    assert last_response.ok?
    assert_includes last_response.body, 'aria-label="Jogos de 08/11"'
    game_cards = last_response.body.scan(%r{<form method="post" action="/agenda" class="game-card".*?</form>}m)
    assert game_cards.any? { |form| form.include?(%(value="#{sunday}")) }
    refute game_cards.any? { |form| form.include?(%(value="#{monday}")) }
  end

  def test_calendar_day_links_use_dia_mes_ano
    get "/?dia=8&mes=11&ano=2026"

    assert_match(%r{class="cal-num" href="/\?dia=9&(?:amp;)?mes=11&(?:amp;)?ano=2026"}, last_response.body)
    refute_match(%r{class="cal-num" href="/\?dia=2026-11-}, last_response.body)
  end

  def test_post_redirects_to_dia_mes_ano
    post "/agenda", {
      sport: "nba",
      day: "2026-11-10",
      title: Faker::Team.name,
      authenticity_token: csrf_token
    }

    assert_equal 302, last_response.status
    assert_match(%r{/\?dia=10&mes=11&ano=2026\z}, last_response.headers["Location"])
  end

  def test_show_links_back_to_the_day_with_dia_mes_ano
    item = AgendaEsportes::App.store.add(
      sport: "automobilismo",
      starts_at: Date.new(2026, 11, 21),
      title: Faker::Vehicle.make_and_model
    )

    get "/agenda/#{item.id}"

    assert_match(%r{href="/\?dia=21&(?:amp;)?mes=11&(?:amp;)?ano=2026"}, last_response.body)
    refute_includes last_response.body, 'href="/?dia=2026-11-21"'
  end

  def test_agenda_index_filters_by_dia_mes_ano
    day_item = AgendaEsportes::App.store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: "Só no dia 8"
    )
    AgendaEsportes::App.store.add(
      sport: "nfl",
      starts_at: Date.new(2026, 11, 9),
      title: "Segunda da NFL"
    )
    AgendaEsportes::App.store.add(
      sport: "nba",
      starts_at: Date.new(2026, 12, 1),
      title: "Dezembro"
    )
    AgendaEsportes::App.store.add(
      sport: "automobilismo",
      starts_at: Date.new(2025, 11, 8),
      title: "Ano passado"
    )

    get "/agenda?dia=8&mes=11&ano=2026"

    assert last_response.ok?
    assert_includes last_response.body, day_item.title
    refute_includes last_response.body, "Segunda da NFL"
    refute_includes last_response.body, "Dezembro"
    refute_includes last_response.body, "Ano passado"
  end

  def test_agenda_index_filters_by_mes_and_ano
    AgendaEsportes::App.store.add(sport: "futebol", starts_at: Date.new(2026, 11, 8), title: "Novembro A")
    AgendaEsportes::App.store.add(sport: "nba", starts_at: Date.new(2026, 11, 20), title: "Novembro B")
    AgendaEsportes::App.store.add(sport: "nfl", starts_at: Date.new(2026, 12, 1), title: "Dezembro")

    get "/agenda?mes=11&ano=2026"

    assert last_response.ok?
    assert_includes last_response.body, "Novembro A"
    assert_includes last_response.body, "Novembro B"
    refute_includes last_response.body, "Dezembro"
  end

  def test_invalid_dia_mes_ano_is_400
    get "/?dia=31&mes=11&ano=2026"

    assert_equal 400, last_response.status
  end

  def test_home_week_strip_links_the_monday_week_with_dia_mes_ano
    seed_tv(
      { starts_at: "2026-11-08T14:00:00-03:00" },
      { starts_at: "2026-11-08T16:00:00-03:00" },
      { starts_at: "2026-11-08T17:00:00-03:00" }
    )
    get "/?dia=8&mes=11&ano=2026"

    assert_match(%r{class="week-strip"}, last_response.body)
    assert_match(%r{class="week-day[^"]*" href="/\?dia=2&(?:amp;)?mes=11&(?:amp;)?ano=2026"}, last_response.body)
    assert_match(%r{class="week-day is-on[^"]*" href="/\?dia=8&(?:amp;)?mes=11&(?:amp;)?ano=2026"}, last_response.body)
    assert_match(%r{3 jogos}i, last_response.body)
    assert_match(%r{href="/\?dia=1&(?:amp;)?mes=11&(?:amp;)?ano=2026"[^>]*>[\s\S]*?semana anterior}i, last_response.body)
    assert_match(%r{href="/\?dia=15&(?:amp;)?mes=11&(?:amp;)?ano=2026"[^>]*>[\s\S]*?próxima semana}i, last_response.body)
  end

  def test_home_sport_pills_count_games_on_the_selected_day
    seed_tv(
      { sport: "futebol", sport_name: "Futebol", starts_at: "2026-11-08T16:00:00-03:00" },
      { sport: "futebol", sport_name: "Futebol", starts_at: "2026-11-08T17:00:00-03:00" },
      { sport: "basquete", sport_name: "Basquete", starts_at: "2026-11-08T21:00:00-03:00" },
      { sport: "basquete", sport_name: "Basquete", starts_at: "2026-11-09T21:00:00-03:00" }
    )
    get "/?dia=8&mes=11&ano=2026"

    assert_match(%r{<label for="f-all" class="sport-pill">[\s\S]*?Todos[\s\S]*?<span class="sport-pill-count">3</span>}i, last_response.body)
    assert_match(%r{<label for="f-futebol" class="sport-pill">[\s\S]*?Futebol[\s\S]*?<span class="sport-pill-count">2</span>}i, last_response.body)
    assert_match(%r{<label for="f-basquete" class="sport-pill">[\s\S]*?Basquete[\s\S]*?<span class="sport-pill-count">1</span>}i, last_response.body)
    refute_includes last_response.body, 'for="f-fut"'
    refute_match(/tênis|tenis|esports|e-sports/i, last_response.body)
  end

  def test_home_lista_is_the_default_view_and_grade_stays_available
    seed_tv
    get "/?dia=8&mes=11&ano=2026"

    assert_match(%r{id="v-lista"[^>]*checked}, last_response.body)
    assert_includes last_response.body, 'id="v-grade"'
    assert_includes last_response.body, 'for="v-lista"'
    assert_includes last_response.body, 'for="v-grade"'
    assert_includes last_response.body, 'class="cal"'
    assert_includes last_response.body, 'class="game-card"'
  end

  def test_week_strip_labels_today_as_hoje
    today = Date.today
    get "/?dia=#{today.day}&mes=#{today.month}&ano=#{today.year}"

    assert last_response.ok?
    assert_match(%r{class="week-day is-on[^"]*"[^>]*>[\s\S]*?hoje}i, last_response.body)
  end

  def test_system_uses_dark_mint_tokens
    css = File.read(File.expand_path("../public/app.css", __dir__))

    assert_match(/--accent:\s*#6eff94/i, css)
    refute_match(/--accent:\s*#c8f542/, css)
    get "/?dia=8&mes=11&ano=2026"
    refute_includes last_response.body, 'data-theme="paper"'
    get "/agenda"
    refute_includes last_response.body, 'data-theme="paper"'
  end

  def test_home_stylesheet_is_cache_busted
    get "/"

    assert_match(%r{href="/app\.css\?v=\d+"}, last_response.body)
  end

  def test_home_nav_does_not_repeat_sport_filters
    seed_tv(sport: "futebol", sport_name: "Futebol")
    get "/?dia=8&mes=11&ano=2026"

    refute_match(%r{<nav class="bar"[^>]*>[\s\S]*?<label for="f-all">Tudo</label>}, last_response.body)
    assert_match(%r{<label for="f-all" class="sport-pill">}, last_response.body)
    get "/agenda"
    assert_match(%r{<nav class="bar"[^>]*>[\s\S]*?<label for="f-all">Tudo</label>}, last_response.body)
  end

  def test_css_hides_the_month_grid_until_grade_is_on
    css = File.read(File.expand_path("../public/app.css", __dir__))

    refute_match(/\.agenda-grid\{grid-template-columns:minmax/, css)
    assert_match(/\.cal-pane\{display:none\}/, css)
    assert_match(/body:has\(#v-grade:checked\) \.cal-pane\{display:block\}/, css)
    assert_match(/body:has\(#v-grade:checked\) \.list-pane\{display:none\}/, css)
  end

  def test_calendar_chips_drop_ua_button_chrome
    css = File.read(File.expand_path("../public/app.css", __dir__))

    assert_match(/\.cal-event button(?:,\s*a\.cal-event)?\{[^}]*appearance:\s*none/m, css)
  end

  def test_home_open_graph_card_is_wired
    get "/"

    assert_includes last_response.body, 'property="og:image" content="https://agenda-esportes.sites.gestaobem.com/og.png"'
    assert_includes last_response.body, 'property="og:image:width" content="1200"'
    assert_includes last_response.body, 'property="og:image:height" content="630"'
    assert_includes last_response.body, 'property="og:image:type" content="image/png"'
    assert_includes last_response.body, 'name="twitter:card" content="summary_large_image"'
    assert_includes last_response.body, 'name="twitter:image" content="https://agenda-esportes.sites.gestaobem.com/og.png"'
  end

  def test_og_html_is_a_dark_mint_week_strip_card
    html = File.read(File.expand_path("../public/og.html", __dir__))

    assert_includes html, "1200px"
    assert_includes html, "630px"
    assert_includes html, "#6eff94"
    assert_includes html, "#0b0e14"
    assert_includes html, "id=\"og\""
    assert_match(/Agenda de esportes/i, html)
    assert_includes html, "Automobilismo"
    refute_match(/tênis|tenis|esports|e-sports|corrida/i, html)
  end

  def test_og_png_is_1200_by_630
    path = File.expand_path("../public/og.png", __dir__)

    assert File.file?(path), "public/og.png missing — render public/og.html"
    header = File.binread(path, 24)
    assert_equal [1200, 630], header[16, 8].unpack("NN")
  end

  def test_home_meta_describes_the_seven_day_tv_window
    get "/"

    assert_includes last_response.body, "Jogos da TV nos próximos 7 dias."
    refute_includes last_response.body, "Futebol, NFL, NBA e automobilismo. Clica no jogo e grava na agenda."
  end

  def test_home_generates_filter_css_for_window_slugs
    seed_tv(sport: "basquete", sport_name: "Basquete")
    get "/?dia=2026-11-08"

    assert_includes last_response.body, "body:has(#f-basquete:checked)"
    assert_includes last_response.body, ".game-card:not([data-s=basquete])"
    refute_includes last_response.body, "#f-fut"
  end

  def test_ge_sync_is_404_when_token_is_unset
    with_sync_token(nil) do
      get "/interno/ge-sync"
    end

    assert_equal 404, last_response.status
  end

  def test_ge_sync_is_401_with_the_wrong_bearer
    with_sync_token("segredo-certo") do
      header "Authorization", "Bearer outro"
      get "/interno/ge-sync"
    end

    assert_equal 401, last_response.status
  end

  def test_ge_sync_upserts_with_a_stub_client
    AgendaEsportes::App.ge_client = EmptyGeClient.new
    with_sync_token("segredo-certo") do
      header "Authorization", "Bearer segredo-certo"
      get "/interno/ge-sync"
    end

    assert_equal 200, last_response.status
    payload = JSON.parse(last_response.body)
    assert_equal true, payload["ok"]
    assert payload["from"]
    assert payload["to"]
    assert payload["synced_at"]
  end

  def test_ge_sync_is_502_when_ge_is_down
    AgendaEsportes::App.ge_client = DownGeClient.new
    with_sync_token("segredo-certo") do
      header "Authorization", "Bearer segredo-certo"
      get "/interno/ge-sync"
    end

    assert_equal 502, last_response.status
    payload = JSON.parse(last_response.body)
    assert_equal false, payload["ok"]
    assert payload["error"]
  end

  def test_home_does_not_lazy_sync_in_test
    AgendaEsportes::App.ge_client = DownGeClient.new
    get "/"

    assert last_response.ok?
  end

  def csrf_token
    get "/"
    last_response.body[/name="authenticity_token"\s+value="([^"]+)"/, 1] ||
      last_response.body[/value="([^"]+)"\s+name="authenticity_token"/, 1] ||
      last_response.body[/name="csrf-token" content="([^"]+)"/, 1]
  end

  def seed_tv(*events, **single)
    events = [single] if events.empty?
    rows = events.each_with_index.map do |event, index|
      {
        ge_id: "ge-#{index + 1}",
        sport: "futebol",
        sport_name: "Futebol",
        title: "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}",
        starts_at: "2026-11-08T17:00:00-03:00",
        timed: true,
        competition: "Liga",
        watch_on: "Globo",
        note: "Liga · pênaltis"
      }.merge(event)
    end
    from = rows.map { |row| Date.iso8601(row[:starts_at][0, 10]) }.min
    AgendaEsportes::App.store.replace_tv_window(rows, from: from, to: from + 6)
    rows
  end

  def with_sync_token(token)
    previous = ENV["GE_SYNC_TOKEN"]
    if token.nil?
      ENV.delete("GE_SYNC_TOKEN")
    else
      ENV["GE_SYNC_TOKEN"] = token
    end
    yield
  ensure
    if previous.nil?
      ENV.delete("GE_SYNC_TOKEN")
    else
      ENV["GE_SYNC_TOKEN"] = previous
    end
  end

  class EmptyGeClient
    def championships_agenda(_date)
      { "data" => { "championshipsAgenda" => [] } }
    end

    def multisport_agenda(_date)
      { "data" => { "multisportTabAgenda" => [] } }
    end
  end

  class DownGeClient
    def championships_agenda(_date)
      raise GeClient::Error, "geql down"
    end

    def multisport_agenda(_date)
      raise GeClient::Error, "geql down"
    end
  end
end
