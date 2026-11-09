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
    assert_includes vasco.where, "Globo"
    assert_match(/pênaltis|penaltis/i, vasco.note)
    assert_match(/1.?0/, vasco.note)
  end

  def test_every_game_has_where_to_watch_and_a_note
    TvGrid::ALL.each do |game|
      refute_empty game.where, "#{game.title} missing where"
      refute_empty game.note, "#{game.title} missing note"
    end
  end

  def test_bills_monday_night_is_the_round_pick
    bills = TvGrid.on(Date.new(2026, 11, 9)).find { |game| game.title == "Bills x Vikings" }

    refute_nil bills
    assert_includes bills.where, "ESPN"
    assert_match(/6.?1/, bills.note)
    assert_equal "22h15", bills.clock
  end

  def test_on_returns_games_for_that_day_only
    monday = TvGrid.on(Date.new(2026, 11, 9))

    assert_equal [
      "Wizards x Pistons",
      "Lakers x Hawks",
      "Grizzlies x Raptors",
      "Bills x Vikings",
      "Nuggets x Rockets",
      "Spurs x Suns"
    ], monday.map(&:title)
    assert_equal "nba", monday.first.sport
    assert_equal "nfl", monday.find { |game| game.title == "Bills x Vikings" }.sport
  end

  def test_empty_day_has_no_games
    assert_empty TvGrid.on(Date.new(2026, 11, 17))
  end

  def test_catalog_never_includes_corrida
    TvGrid::ALL.each do |game|
      refute_equal "corrida", game.sport
      refute_match(/corrida/i, game.title)
      assert_includes SportsCatalog.slugs, game.sport
    end
  end

  def test_tuesday_nba_is_sorted_by_tipoff
    tuesday = TvGrid.on(Date.new(2026, 11, 10))
    titles = tuesday.map(&:title)

    assert_equal ["Bucks x Knicks", "Celtics x 76ers"], titles
    assert_equal "21h30", tuesday.first.clock
    celtics = tuesday.find { |game| game.title == "Celtics x 76ers" }
    assert_equal "22h", celtics.clock
    assert_includes celtics.where, "Prime"
  end

  def test_wednesday_nba_opens_with_thunder_at_one_am
    wednesday = TvGrid.on(Date.new(2026, 11, 11))

    assert_equal [
      "Thunder x Blazers",
      "Cavaliers x Knicks",
      "Lakers x Bucks",
      "Warriors x Rockets"
    ], wednesday.map(&:title)
    thunder = wednesday.first
    assert_equal "1h", thunder.clock
    assert_includes thunder.where, "Prime"
    cavs = wednesday.find { |game| game.title == "Cavaliers x Knicks" }
    assert_equal "21h", cavs.clock
    assert_includes cavs.where, "ESPN"
  end

  def test_thursday_has_prime_nba_and_thursday_night_football
    thursday = TvGrid.on(Date.new(2026, 11, 12))

    assert_equal [
      "Raptors x 76ers",
      "Mavericks x Timberwolves",
      "Commanders x Giants"
    ], thursday.map(&:title)
    tnf = thursday.find { |game| game.title == "Commanders x Giants" }
    assert_equal "nfl", tnf.sport
    assert_equal "22h15", tnf.clock
    assert_includes tnf.where, "sportv"
    raptors = thursday.first
    assert_equal "21h", raptors.clock
    assert_includes raptors.where, "Prime"
  end

  def test_friday_prime_is_knicks_pacers_then_warriors_spurs
    friday = TvGrid.on(Date.new(2026, 11, 13))

    assert_equal ["Knicks x Pacers", "Warriors x Spurs"], friday.map(&:title)
    knicks = friday.first
    assert_equal "21h", knicks.clock
    assert_includes knicks.where, "Prime"
    refute_includes friday.map(&:title), "Knicks x Lakers"
  end

  def test_saturday_serie_b_finale_then_pistons_heat
    saturday = TvGrid.on(Date.new(2026, 11, 14))

    assert_equal [
      "Criciúma x Novorizontino",
      "Fortaleza x Vila Nova",
      "Juventude x Botafogo-SP",
      "Pistons x Heat"
    ], saturday.map(&:title)
    criciuma = saturday.first
    assert_equal "futebol", criciuma.sport
    assert_equal "16h30", criciuma.clock
    assert_includes criciuma.where, "Disney+"
    assert_match(/t[íi]tulo/i, criciuma.note)
    heat = saturday.last
    assert_equal "22h", heat.clock
    assert_includes heat.where, "ESPN"
  end

  def test_sunday_week_ten_runs_munich_to_sunday_night
    sunday = TvGrid.on(Date.new(2026, 11, 15))

    assert_equal [
      "Patriots x Lions",
      "Vikings x Packers",
      "Bills x Jets",
      "Lakers x Suns",
      "49ers x Cowboys",
      "Mavericks x Celtics",
      "Steelers x Bengals"
    ], sunday.map(&:title)
    munich = sunday.first
    assert_equal "11h30", munich.clock
    assert_match(/Munique|Allianz/i, munich.note)
    assert_includes munich.where, "sportv"
    snf = sunday.last
    assert_equal "22h20", snf.clock
    assert_includes snf.where, "sportv"
    mavs = sunday.find { |game| game.title == "Mavericks x Celtics" }
    assert_equal "20h", mavs.clock
    assert_includes mavs.where, "Prime"
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
