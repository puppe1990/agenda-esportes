# frozen_string_literal: true

require_relative "support/app_test_case"

class AppHomeTest < AppTestCase
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

  def test_home_nav_does_not_repeat_sport_filters
    seed_tv(sport: "futebol", sport_name: "Futebol")
    get "/?dia=8&mes=11&ano=2026"

    refute_match(%r{<nav class="bar"[^>]*>[\s\S]*?<label for="f-all">Tudo</label>}, last_response.body)
    assert_match(%r{<label for="f-all" class="sport-pill">}, last_response.body)
    get "/agenda"
    assert_match(%r{<nav class="bar"[^>]*>[\s\S]*?<label for="f-all">Tudo</label>}, last_response.body)
  end

  def test_home_generates_filter_css_for_window_slugs
    seed_tv(sport: "basquete", sport_name: "Basquete")
    get "/?dia=2026-11-08"

    assert_includes last_response.body, "body:has(#f-basquete:checked)"
    assert_includes last_response.body, ".game-card:not([data-s=basquete])"
    refute_includes last_response.body, "#f-fut"
  end

  def test_home_meta_describes_the_seven_day_tv_window
    get "/"

    assert_includes last_response.body, "Jogos da TV nos próximos 7 dias."
    refute_includes last_response.body, "Futebol, NFL, NBA e automobilismo. Clica no jogo e grava na agenda."
  end
end
