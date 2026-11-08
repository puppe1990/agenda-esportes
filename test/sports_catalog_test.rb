# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/sports_catalog"

class SportsCatalogTest < Minitest::Test
  def test_catalog_includes_automobilismo_and_the_tv_sports
    slugs = SportsCatalog.slugs

    assert_includes slugs, "automobilismo"
    assert_includes slugs, "futebol"
    assert_includes slugs, "nfl"
    assert_includes slugs, "nba"
  end

  def test_catalog_excludes_corrida
    slugs = SportsCatalog.slugs

    refute_includes slugs, "corrida"
    refute_includes slugs, "run"
    SportsCatalog::ALL.each do |sport|
      refute_match(/corrida/i, sport.name)
      refute_match(/corrida/i, sport.slug)
    end
  end

  def test_find_bang_returns_automobilismo
    sport = SportsCatalog.find!("automobilismo")

    assert_equal "automobilismo", sport.slug
    assert_equal "Automobilismo", sport.name
  end

  def test_find_bang_rejects_corrida_with_the_value_received
    error = assert_raises(SportsCatalog::UnknownSport) do
      SportsCatalog.find!("corrida")
    end

    assert_match(/corrida/, error.message)
    assert_match(/automobilismo/, error.message)
  end

  def test_each_catalog_row_has_slug_and_name
    SportsCatalog::ALL.each do |sport|
      refute_nil sport.slug
      refute_nil sport.name
      refute_empty sport.slug
      refute_empty sport.name
    end
  end
end
