# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/sport_slug"

class SportSlugTest < Minitest::Test
  def test_downcases_a_plain_name
    assert_equal "basquete", SportSlug.call("Basquete")
  end

  def test_strips_accents
    assert_equal "volei", SportSlug.call("Vôlei")
  end

  def test_hyphenates_spaces
    assert_equal "futebol-americano", SportSlug.call("Futebol americano")
  end

  def test_faker_name_is_a_slug
    name = "#{Faker::Sport.sport} #{Faker::Alphanumeric.alpha(number: 4)}"
    slug = SportSlug.call(name)

    assert_match(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, slug)
    refute_empty slug
  end
end
