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

  def test_update_changes_sport_title_and_day
    item = @store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: Faker::Sports::Football.team
    )
    title = Faker::Team.name

    updated = @store.update(
      item.id,
      sport: "nba",
      starts_at: Date.new(2026, 11, 20),
      title: title
    )

    assert_equal item.id, updated.id
    assert_equal "nba", updated.sport
    assert_equal title, updated.title
    assert_equal Date.new(2026, 11, 20), updated.starts_on
    assert_equal updated, @store.find(item.id)
  end

  def test_update_empty_title_uses_the_catalog_name
    item = @store.add(sport: "nfl", starts_at: Date.new(2026, 11, 9), title: Faker::Team.name)

    updated = @store.update(item.id, sport: "automobilismo", starts_at: item.starts_on, title: "  ")

    assert_equal "Automobilismo", updated.title
    assert_equal "automobilismo", updated.sport
  end

  def test_update_refuses_corrida
    item = @store.add(sport: "nba", starts_at: Date.new(2026, 11, 10), title: Faker::Team.name)

    error = assert_raises(SportsCatalog::UnknownSport) do
      @store.update(item.id, sport: "corrida", starts_at: item.starts_on, title: Faker::Lorem.word)
    end

    assert_match(/corrida/, error.message)
    assert_equal "nba", @store.find(item.id).sport
  end

  def test_update_missing_raises_not_found
    error = assert_raises(AgendaStore::NotFound) do
      @store.update(9_999, sport: "nba", starts_at: Date.new(2026, 11, 10), title: Faker::Team.name)
    end

    assert_match(/9999/, error.message)
  end

  def test_delete_missing_raises_not_found
    error = assert_raises(AgendaStore::NotFound) do
      @store.delete(4_321)
    end

    assert_match(/4321/, error.message)
  end

  def test_find_unknown_id_returns_nil
    assert_nil @store.find(123)
    assert_nil @store.find("abc")
  end

  def test_add_keeps_kickoff_and_note
    note = Faker::Lorem.sentence

    item = @store.add(
      sport: "futebol",
      starts_at: Date.new(2026, 11, 8),
      title: "Vasco x Palmeiras",
      kicks_at: "17h",
      note: note,
      watch_on: "Globo, ge tv"
    )

    assert_equal "17h", item.kicks_at
    assert_equal note, item.note
    assert_equal "Globo, ge tv", item.watch_on
    assert_equal "17h", item.clock
  end

  def test_item_without_kickoff_clock_is_the_date
    item = @store.add(
      sport: "nba",
      starts_at: Date.new(2026, 11, 11),
      title: Faker::Team.name
    )

    assert_nil item.kicks_at
    assert_nil item.note
    assert_equal "11/11", item.clock
  end

  def test_survives_reopen_with_kickoff_and_note
    note = Faker::Lorem.sentence
    @store.add(
      sport: "nfl",
      starts_at: Date.new(2026, 11, 9),
      title: "Bills x Vikings",
      kicks_at: "22h15",
      note: note,
      watch_on: "ESPN"
    )

    item = AgendaStore.new(@path).all.first

    assert_equal "22h15", item.kicks_at
    assert_equal note, item.note
    assert_equal "ESPN", item.watch_on
  end

  def test_migrates_kickoff_columns_onto_an_existing_table
    path = File.join(@dir, "legacy.sqlite3")
    SQLite3::Database.new(path).execute <<~SQL
      CREATE TABLE agenda_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sport TEXT NOT NULL,
        title TEXT NOT NULL,
        starts_on TEXT NOT NULL
      )
    SQL

    store = AgendaStore.new(path)
    note = Faker::Lorem.sentence
    item = store.add(
      sport: "nfl",
      starts_at: Date.new(2026, 11, 9),
      title: "Bills x Vikings",
      kicks_at: "22h15",
      note: note
    )

    assert_equal "22h15", item.kicks_at
    assert_equal note, item.note
  end
end
