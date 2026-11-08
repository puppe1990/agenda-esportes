# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/agenda_store"

class AgendaStoreTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("agenda-esportes-")
    @path = File.join(@dir, "agenda.sqlite3")
    @store = AgendaStore.new(@path)
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def test_adds_a_faker_backed_automobilismo_item
    title = "#{Faker::Vehicle.make} #{Faker::Vehicle.model}"
    day = Date.new(2026, 11, Faker::Number.between(from: 1, to: 28))

    item = @store.add(sport: "automobilismo", starts_at: day, title: title)

    assert item.id.positive?
    assert_equal "automobilismo", item.sport
    assert_equal title, item.title
    assert_equal day, item.starts_on
  end

  def test_empty_title_uses_the_catalog_name
    item = @store.add(
      sport: "nba",
      starts_at: Date.new(2026, 11, 10),
      title: "   "
    )

    assert_equal "NBA", item.title
  end

  def test_refuses_corrida
    error = assert_raises(SportsCatalog::UnknownSport) do
      @store.add(
        sport: "corrida",
        starts_at: Date.new(2026, 11, 8),
        title: Faker::Lorem.word
      )
    end

    assert_match(/corrida/, error.message)
    assert_empty @store.all
  end

  def test_items_on_filters_by_day
    day = Date.new(2026, 11, 8)
    @store.add(sport: "futebol", starts_at: day, title: Faker::Sports::Football.team)
    @store.add(sport: "nfl", starts_at: Date.new(2026, 11, 9), title: Faker::Team.name)

    on_day = @store.items_on(day)

    assert_equal 1, on_day.size
    assert_equal "futebol", on_day.first.sport
  end

  def test_days_with_items_in_month
    @store.add(sport: "nba", starts_at: Date.new(2026, 11, 8), title: Faker::Team.name)
    @store.add(sport: "nba", starts_at: Date.new(2026, 11, 10), title: Faker::Team.name)
    @store.add(sport: "nba", starts_at: Date.new(2026, 12, 6), title: Faker::Team.name)

    days = @store.days_with_items(2026, 11)

    assert_equal [Date.new(2026, 11, 8), Date.new(2026, 11, 10)], days
  end

  def test_survives_reopen
    title = Faker::Movie.title
    @store.add(sport: "automobilismo", starts_at: Date.new(2026, 11, 8), title: title)

    reopened = AgendaStore.new(@path)
    item = reopened.all.first

    assert_equal title, item.title
    assert_equal "automobilismo", item.sport
  end

  def test_delete_removes_the_row
    item = @store.add(sport: "nfl", starts_at: Date.new(2026, 11, 9), title: Faker::Team.name)

    @store.delete(item.id)

    assert_empty @store.all
  end
end
