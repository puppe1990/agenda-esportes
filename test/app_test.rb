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

  def test_home_renders_sport_cards_that_post_straight_into_the_agenda
    get "/"

    assert_includes last_response.body, "agendinha"
    assert_includes last_response.body, 'class="sport-card"'
    assert_includes last_response.body, 'value="automobilismo"'
    assert_includes last_response.body, 'value="futebol"'
    refute_includes last_response.body, "<select"
    refute_includes last_response.body, "Colocar na agenda"
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

  def test_home_shows_interlagos_on_sunday
    get "/"

    assert_includes last_response.body, "Interlagos"
    assert_includes last_response.body, "Grande Prêmio de São Paulo"
  end

  def csrf_token
    get "/"
    last_response.body[/name="authenticity_token"\s+value="([^"]+)"/, 1] ||
      last_response.body[/value="([^"]+)"\s+name="authenticity_token"/, 1]
  end
end
