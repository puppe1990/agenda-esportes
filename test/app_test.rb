# frozen_string_literal: true

require_relative "test_helper"
require "rack/test"

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
  end

  def test_home_lists_automobilismo_instead_of_corrida
    get "/"

    assert last_response.ok?
    assert_includes last_response.body, "Automobilismo"
    refute_includes last_response.body, "Corrida"
    refute_match(/>corrida</i, last_response.body)
  end

  def test_home_renders_game_cards_that_post_the_match_into_the_agenda
    get "/?dia=2026-11-08"

    assert_includes last_response.body, "agendinha"
    assert_includes last_response.body, 'class="game-card"'
    assert_includes last_response.body, "Vasco x Palmeiras"
    assert_includes last_response.body, 'name="title"'
    assert_includes last_response.body, 'value="Vasco x Palmeiras"'
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
    get "/?dia=2026-11-08"

    assert_includes last_response.body, 'class="game-card-where"'
    assert_includes last_response.body, 'class="game-card-note"'
    assert_includes last_response.body, "Globo"
    assert_match(/pênaltis|penaltis/i, last_response.body)
    assert_includes last_response.body, "Band"
    assert_includes last_response.body, "CazéTV"
  end

  def test_monday_game_card_shows_espn_and_standings
    get "/?dia=2026-11-09"

    assert_includes last_response.body, "Bills x Vikings"
    assert_includes last_response.body, "ESPN"
    assert_match(/6.?1/, last_response.body)
  end

  def test_home_renders_sport_cards_when_the_day_has_no_tv_games
    get "/?dia=2026-11-11"

    assert_includes last_response.body, 'class="sport-card"'
    assert_includes last_response.body, 'value="automobilismo"'
    assert_includes last_response.body, 'value="futebol"'
    refute_includes last_response.body, 'class="game-card"'
    refute_includes last_response.body, "<select"
    refute_includes last_response.body, 'value="corrida"'
    assert_equal 4, last_response.body.scan(/class="sport-card"/).size
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
    post "/agenda", {
      sport: "futebol",
      day: "2026-11-08",
      title: "Vasco x Palmeiras",
      authenticity_token: csrf_token
    }

    assert_equal 302, last_response.status
    follow_redirect!

    stored = AgendaEsportes::App.store.items_on(Date.new(2026, 11, 8))
    assert_equal 1, stored.size
    assert_equal "futebol", stored.first.sport
    assert_equal "Vasco x Palmeiras", stored.first.title
    assert_includes last_response.body, "Vasco x Palmeiras"
    assert_includes last_response.body, "Futebol"
    refute_match(
      %r{<h3><a href="/agenda/#{stored.first.id}">Futebol</a></h3>},
      last_response.body
    )
  end

  def test_post_game_keeps_kickoff_and_note_on_the_agenda
    note = "São Januário. Ida 1–0 Palmeiras. Sem prorrogação: empate no agregado vai a pênaltis."

    post "/agenda", {
      sport: "futebol",
      day: "2026-11-08",
      title: "Vasco x Palmeiras",
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
    get "/?dia=2026-11-08"

    assert_includes last_response.body, 'class="cal"'
    assert_includes last_response.body, 'class="game-card"'
    assert_includes last_response.body, "Vasco x Palmeiras"
    assert_includes last_response.body, "Grande Prêmio de São Paulo"
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
    AgendaEsportes::App.store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: "Vasco x Palmeiras"
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

  def csrf_token
    get "/"
    last_response.body[/name="authenticity_token"\s+value="([^"]+)"/, 1] ||
      last_response.body[/value="([^"]+)"\s+name="authenticity_token"/, 1]
  end
end
