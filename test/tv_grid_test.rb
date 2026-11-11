# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/agenda_store"
require_relative "../lib/tv_grid"

class TvGridTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("agenda-tv-")
    @store = AgendaStore.new(File.join(@dir, "agenda.sqlite3"))
    TvGrid.store = @store
  end

  def teardown
    TvGrid.store = nil
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def test_on_maps_store_rows_to_events_sorted_by_kickoff
    home = Faker::Sports::Basketball.team
    away = Faker::Sports::Basketball.team
    late = "#{home} x #{away}"
    early = "#{Faker::Team.name} x #{Faker::Team.name}"
    @store.replace_tv_window(
      [
        row(ge_id: "2", title: late, starts_at: "2026-11-11T22:00:00-03:00", sport: "basquete",
            sport_name: "Basquete", competition: "NBA", watch_on: "League Pass", note: "NBA · regular"),
        row(ge_id: "1", title: early, starts_at: "2026-11-11T19:30:00-03:00", sport: "basquete",
            sport_name: "Basquete", competition: "NBB", watch_on: nil, note: "NBB · regular")
      ],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )

    games = TvGrid.on(Date.new(2026, 11, 11))

    assert_equal [early, late], games.map(&:title)
    assert_equal "19h30", games.first.clock
    assert_equal "22h", games.last.clock
    assert_equal "basquete", games.last.sport
    assert_equal "League Pass", games.last.where
    assert_equal "NBA · regular", games.last.note
  end

  def test_untimed_clock_uses_the_day_and_month
    @store.replace_tv_window(
      [row(ge_id: "9", title: "GP x Grid", starts_at: "2026-12-06T00:00:00-03:00", timed: false,
           sport: "automobilismo", sport_name: "Automobilismo", competition: "F1",
           watch_on: "Band", note: "F1 · Abu Dhabi")],
      from: Date.new(2026, 12, 6),
      to: Date.new(2026, 12, 12)
    )

    game = TvGrid.on(Date.new(2026, 12, 6)).first

    assert_equal "6 dez", game.clock
  end

  def test_empty_day_has_no_games
    assert_empty TvGrid.on(Date.new(2026, 11, 17))
  end

  def test_on_does_not_leak_other_days
    @store.replace_tv_window(
      [
        row(ge_id: "1", title: "A x B", starts_at: "2026-11-11T20:00:00-03:00"),
        row(ge_id: "2", title: "C x D", starts_at: "2026-11-12T20:00:00-03:00")
      ],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )

    assert_equal ["A x B"], TvGrid.on(Date.new(2026, 11, 11)).map(&:title)
  end

  private

  def row(ge_id:, title:, starts_at:, sport: "futebol", sport_name: "Futebol", competition: "X",
          watch_on: "ESPN", note: "X · fase", timed: true)
    {
      ge_id: ge_id,
      sport: sport,
      sport_name: sport_name,
      title: title,
      starts_at: starts_at,
      timed: timed,
      competition: competition,
      watch_on: watch_on,
      note: note
    }
  end
end
