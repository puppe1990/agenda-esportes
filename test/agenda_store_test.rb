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

  def test_items_on_orders_by_kickoff
    day = Date.new(2026, 11, 8)
    late = Faker::Team.name
    early = Faker::Sports::Football.team
    mid = "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}"

    @store.add(sport: "nfl", starts_at: day, title: late, kicks_at: "22h20")
    @store.add(sport: "nba", starts_at: day, title: Faker::Team.name)
    @store.add(sport: "futebol", starts_at: day, title: early, kicks_at: "11h")
    @store.add(sport: "futebol", starts_at: day, title: mid, kicks_at: "17h30")

    assert_equal ["11h", "17h30", "22h20", "08/11"], @store.items_on(day).map(&:clock)
  end

  def test_all_orders_by_day_then_kickoff
    late_sunday = Faker::Team.name
    monday = Faker::Team.name
    early_sunday = Faker::Sports::Football.team

    @store.add(sport: "nfl", starts_at: Date.new(2026, 11, 8), title: late_sunday, kicks_at: "22h15")
    @store.add(sport: "nba", starts_at: Date.new(2026, 11, 9), title: monday, kicks_at: "19h30")
    @store.add(sport: "futebol", starts_at: Date.new(2026, 11, 8), title: early_sunday, kicks_at: "11h")

    assert_equal [early_sunday, late_sunday, monday], @store.all.map(&:title)
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

  def test_replace_tv_window_upserts_and_lists_by_day
    home = Faker::Team.name
    away = Faker::Team.name
    title = "#{home} x #{away}"
    @store.replace_tv_window(
      [
        tv_event(ge_id: "358001", sport: "basquete", sport_name: "Basquete", title: title,
                 starts_at: "2026-11-11T22:00:00-03:00", competition: "NBA")
      ],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )

    games = @store.tv_events_on(Date.new(2026, 11, 11))
    assert_equal 1, games.size
    assert_equal title, games.first[:title]
    assert_equal "basquete", games.first[:sport]
    assert_empty @store.tv_events_on(Date.new(2026, 11, 12))
  end

  def test_replace_tv_window_prunes_ids_missing_from_the_batch
    @store.replace_tv_window(
      [
        tv_event(ge_id: "1", title: "A x B", starts_at: "2026-11-11T20:00:00-03:00"),
        tv_event(ge_id: "2", title: "C x D", starts_at: "2026-11-11T21:00:00-03:00")
      ],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )
    @store.replace_tv_window(
      [tv_event(ge_id: "1", title: "A x B", starts_at: "2026-11-11T20:00:00-03:00")],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )

    titles = @store.tv_events_on(Date.new(2026, 11, 11)).map { |row| row[:title] }
    assert_equal ["A x B"], titles
  end

  def test_replace_tv_window_prunes_events_outside_the_window
    @store.replace_tv_window(
      [tv_event(ge_id: "old", title: "Old x Game", starts_at: "2026-11-01T20:00:00-03:00")],
      from: Date.new(2026, 11, 1),
      to: Date.new(2026, 11, 7)
    )
    @store.replace_tv_window(
      [tv_event(ge_id: "new", title: "New x Game", starts_at: "2026-11-11T20:00:00-03:00")],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )

    assert_empty @store.tv_events_on(Date.new(2026, 11, 1))
    assert_equal ["New x Game"], @store.tv_events_on(Date.new(2026, 11, 11)).map { |row| row[:title] }
  end

  def test_sports_in_tv_window_lists_distinct_names
    @store.replace_tv_window(
      [
        tv_event(ge_id: "1", sport: "basquete", sport_name: "Basquete", title: "A x B",
                 starts_at: "2026-11-11T20:00:00-03:00"),
        tv_event(ge_id: "2", sport: "basquete", sport_name: "Basquete", title: "C x D",
                 starts_at: "2026-11-12T20:00:00-03:00"),
        tv_event(ge_id: "3", sport: "volei", sport_name: "Vôlei", title: "E x F",
                 starts_at: "2026-11-11T19:00:00-03:00")
      ],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )

    slugs = @store.sports_in_tv_window.map(&:slug)
    assert_equal %w[basquete volei], slugs
    assert_equal "Vôlei", @store.sports_in_tv_window.find { |sport| sport.slug == "volei" }.name
  end

  def test_records_sync_state
    now = Time.parse("2026-11-11T09:00:00-03:00")
    @store.record_sync!(synced_at: now, event_count: 4, error: nil)

    state = @store.sync_state
    assert_equal now.iso8601, Time.parse(state[:synced_at]).iso8601
    assert_equal 4, state[:event_count]
    assert_nil state[:error]
  end

  def test_find_sport_bang_accepts_a_synced_slug
    @store.replace_tv_window(
      [tv_event(ge_id: "1", sport: "basquete", sport_name: "Basquete", title: "A x B",
                starts_at: "2026-11-11T20:00:00-03:00")],
      from: Date.new(2026, 11, 11),
      to: Date.new(2026, 11, 17)
    )

    sport = @store.find_sport!("basquete")
    assert_equal "basquete", sport.slug
    assert_equal "Basquete", sport.name
  end

  private

  def tv_event(ge_id:, title:, starts_at:, sport: "futebol", sport_name: "Futebol", competition: "NBA")
    {
      ge_id: ge_id,
      sport: sport,
      sport_name: sport_name,
      title: title,
      starts_at: starts_at,
      timed: true,
      competition: competition,
      watch_on: "ESPN",
      note: "#{competition} · regular"
    }
  end
end
