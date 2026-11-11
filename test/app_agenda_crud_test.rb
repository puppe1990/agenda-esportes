# frozen_string_literal: true

require_relative "support/app_test_case"

class AppAgendaCrudTest < AppTestCase
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
end
