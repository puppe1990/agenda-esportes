# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/tv_grid"

class TvGridTest < Minitest::Test
  def test_sunday_includes_vasco_palmeiras_as_futebol
    games = TvGrid.on(Date.new(2026, 11, 8))
    vasco = games.find { |game| game.title == "Vasco x Palmeiras" }

    refute_nil vasco
    assert_equal "futebol", vasco.sport
    assert_equal "Copa do Brasil · volta da semi", vasco.competition
    assert_equal "17h", vasco.clock
  end

  def test_on_returns_games_for_that_day_only
    monday = TvGrid.on(Date.new(2026, 11, 9))

    assert_equal ["Bills x Vikings"], monday.map(&:title)
    assert_equal "nfl", monday.first.sport
  end

  def test_empty_day_has_no_games
    assert_empty TvGrid.on(Date.new(2026, 11, 11))
  end

  def test_catalog_never_includes_corrida
    TvGrid::ALL.each do |game|
      refute_equal "corrida", game.sport
      refute_match(/corrida/i, game.title)
      assert_includes SportsCatalog.slugs, game.sport
    end
  end

  def test_tuesday_nba_is_sorted_by_tipoff
    titles = TvGrid.on(Date.new(2026, 11, 10)).map(&:title)

    assert_equal ["Bucks x Knicks", "Celtics x 76ers"], titles
  end

  def test_same_kickoff_keeps_editorial_order
    titles = TvGrid.on(Date.new(2026, 11, 8)).map(&:title)

    palace = titles.index("Crystal Palace x Liverpool")
    braga = titles.index("RB Bragantino x Internacional")
    refute_nil palace
    refute_nil braga
    assert palace < braga
  end
end
