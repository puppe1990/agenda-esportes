# frozen_string_literal: true

require_relative "support/app_test_case"

class AppCalendarTest < AppTestCase
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

  def test_invalid_dia_mes_ano_is_400
    get "/?dia=31&mes=11&ano=2026"

    assert_equal 400, last_response.status
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
end
