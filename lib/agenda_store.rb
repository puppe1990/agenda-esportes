# frozen_string_literal: true

require "sqlite3"
require "date"
require "time"
require "fileutils"
require_relative "sports_catalog"

class AgendaStore
  class NotFound < StandardError; end

  Item = Struct.new(:id, :sport, :title, :starts_on, :kicks_at, :note, :watch_on, keyword_init: true) do
    def clock
      return kicks_at unless kicks_at.to_s.strip.empty?

      starts_on.strftime("%d/%m")
    end

    def kickoff_minutes
      match = kicks_at.to_s.strip.match(/\A(\d{1,2})h(\d{2})?\z/)
      return 24 * 60 unless match

      (match[1].to_i * 60) + (match[2] || "0").to_i
    end
  end

  def initialize(path)
    FileUtils.mkdir_p(File.dirname(path))
    @db = SQLite3::Database.new(path)
    @db.results_as_hash = true
    @db.execute("PRAGMA foreign_keys = ON")
    migrate
  end

  def add(sport:, starts_at:, title: nil, kicks_at: nil, note: nil, watch_on: nil)
    catalog = find_sport!(sport)
    cleaned = blank_to_catalog_name(title, catalog)
    day = coerce_date(starts_at)

    @db.execute(
      "INSERT INTO agenda_items (sport, title, starts_on, kicks_at, note, watch_on) VALUES (?, ?, ?, ?, ?, ?)",
      [catalog.slug, cleaned, day.iso8601, blank_to_nil(kicks_at), blank_to_nil(note), blank_to_nil(watch_on)]
    )

    find(@db.last_insert_row_id)
  end

  def all
    sort_by_kickoff(@db.execute("SELECT * FROM agenda_items").map { |row| hydrate(row) })
  end

  def items_on(day)
    date = coerce_date(day)
    sort_by_kickoff(
      @db.execute(
        "SELECT * FROM agenda_items WHERE starts_on = ?",
        [date.iso8601]
      ).map { |row| hydrate(row) }
    )
  end

  def days_with_items(year, month)
    start = Date.new(year, month, 1)
    stop = Date.new(year, month, -1)
    @db.execute(
      "SELECT DISTINCT starts_on FROM agenda_items WHERE starts_on >= ? AND starts_on <= ? ORDER BY starts_on",
      [start.iso8601, stop.iso8601]
    ).map { |row| Date.iso8601(row["starts_on"]) }
  end

  def update(id, sport:, starts_at:, title: nil, kicks_at: nil, note: nil, watch_on: nil)
    current = require_item(id)
    catalog = find_sport!(sport)
    cleaned = blank_to_catalog_name(title, catalog)
    day = coerce_date(starts_at)

    @db.execute(
      "UPDATE agenda_items SET sport = ?, title = ?, starts_on = ?, kicks_at = ?, note = ?, watch_on = ? WHERE id = ?",
      [catalog.slug, cleaned, day.iso8601, blank_to_nil(kicks_at), blank_to_nil(note), blank_to_nil(watch_on), current.id]
    )

    find(current.id)
  end

  def delete(id)
    current = require_item(id)
    @db.execute("DELETE FROM agenda_items WHERE id = ?", [current.id])
    current
  end

  def find(id)
    key = Integer(id, exception: false)
    return nil unless key

    row = @db.get_first_row("SELECT * FROM agenda_items WHERE id = ?", [key])
    hydrate(row) if row
  end

  def find_sport!(slug)
    row = @db.get_first_row("SELECT slug, name FROM sports WHERE slug = ?", [slug.to_s])
    return SportsCatalog::Item.new(slug: row["slug"], name: row["name"]) if row

    raise SportsCatalog::UnknownSport,
          "esporte desconhecido: #{slug.inspect} (esperado: #{sport_slugs.join(', ')})"
  end

  def sports
    @db.execute("SELECT slug, name FROM sports ORDER BY name COLLATE NOCASE").map do |row|
      SportsCatalog::Item.new(slug: row["slug"], name: row["name"])
    end
  end

  def sports_in_tv_window
    @db.execute(<<~SQL).map { |row| SportsCatalog::Item.new(slug: row["sport"], name: row["sport_name"]) }
      SELECT sport, sport_name FROM tv_events GROUP BY sport ORDER BY sport
    SQL
  end

  def tv_events_on(day)
    date = coerce_date(day).iso8601
    @db.execute(
      "SELECT * FROM tv_events WHERE substr(starts_at, 1, 10) = ? ORDER BY starts_at, ge_id",
      [date]
    ).map { |row| hydrate_tv(row) }
  end

  def tv_events_grouped
    @db.execute("SELECT * FROM tv_events ORDER BY starts_at, ge_id").each_with_object({}) do |row, hash|
      event = hydrate_tv(row)
      day = Date.iso8601(event[:starts_at][0, 10])
      (hash[day] ||= []) << event
    end
  end

  def replace_tv_window(events, from:, to:, prune_dates: nil)
    @db.transaction do
      upsert_tv_events(events)
      delete_tv_outside_window(from, to)
      prune_tv_on_dates(events, Array(prune_dates || (from..to).to_a))
    end
  end

  def record_sync!(synced_at:, event_count:, error: nil)
    @db.execute("DELETE FROM sync_state")
    @db.execute(
      "INSERT INTO sync_state (id, synced_at, event_count, error) VALUES (1, ?, ?, ?)",
      [synced_at.iso8601, event_count, error]
    )
  end

  def sync_state
    row = @db.get_first_row("SELECT * FROM sync_state WHERE id = 1")
    return nil unless row

    { synced_at: row["synced_at"], event_count: row["event_count"], error: row["error"] }
  end

  private

  def migrate
    @db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS agenda_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sport TEXT NOT NULL,
        title TEXT NOT NULL,
        starts_on TEXT NOT NULL,
        kicks_at TEXT,
        note TEXT,
        watch_on TEXT
      )
    SQL
    ensure_column("kicks_at")
    ensure_column("note")
    ensure_column("watch_on")
    @db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS sports (
        slug TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    SQL
    @db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS tv_events (
        ge_id TEXT PRIMARY KEY,
        sport TEXT NOT NULL,
        sport_name TEXT NOT NULL,
        title TEXT NOT NULL,
        starts_at TEXT NOT NULL,
        timed INTEGER NOT NULL DEFAULT 1,
        competition TEXT,
        watch_on TEXT,
        note TEXT
      )
    SQL
    @db.execute("CREATE INDEX IF NOT EXISTS tv_events_starts_at ON tv_events (starts_at)")
    @db.execute("CREATE INDEX IF NOT EXISTS tv_events_sport ON tv_events (sport)")
    @db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS sync_state (
        id INTEGER PRIMARY KEY,
        synced_at TEXT NOT NULL,
        event_count INTEGER NOT NULL,
        error TEXT
      )
    SQL
    seed_sports
  end

  def seed_sports
    SportsCatalog::ALL.each do |sport|
      @db.execute(
        "INSERT OR IGNORE INTO sports (slug, name) VALUES (?, ?)",
        [sport.slug, sport.name]
      )
    end
  end

  def upsert_tv_events(events)
    events.each do |event|
      ensure_sport(event[:sport], event[:sport_name])
      @db.execute(<<~SQL, tv_row(event))
        INSERT INTO tv_events (ge_id, sport, sport_name, title, starts_at, timed, competition, watch_on, note)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(ge_id) DO UPDATE SET
          sport = excluded.sport,
          sport_name = excluded.sport_name,
          title = excluded.title,
          starts_at = excluded.starts_at,
          timed = excluded.timed,
          competition = excluded.competition,
          watch_on = excluded.watch_on,
          note = excluded.note
      SQL
    end
  end

  def delete_tv_outside_window(from, to)
    @db.execute(
      "DELETE FROM tv_events WHERE substr(starts_at, 1, 10) < ? OR substr(starts_at, 1, 10) > ?",
      [coerce_date(from).iso8601, coerce_date(to).iso8601]
    )
  end

  # Failed GE days stay in prune_dates' complement so a 422/timeout
  # does not wipe yesterday's rows for that date.
  def prune_tv_on_dates(events, dates)
    return if dates.empty?

    ids = events.map { |event| event[:ge_id].to_s }
    day_keys = dates.map { |day| coerce_date(day).iso8601 }
    date_ph = Array.new(day_keys.size, "?").join(",")
    if ids.empty?
      @db.execute(
        "DELETE FROM tv_events WHERE substr(starts_at, 1, 10) IN (#{date_ph})",
        day_keys
      )
      return
    end

    id_ph = Array.new(ids.size, "?").join(",")
    @db.execute(
      "DELETE FROM tv_events WHERE substr(starts_at, 1, 10) IN (#{date_ph}) AND ge_id NOT IN (#{id_ph})",
      day_keys + ids
    )
  end

  def ensure_sport(slug, name)
    @db.execute(
      "INSERT INTO sports (slug, name) VALUES (?, ?) ON CONFLICT(slug) DO UPDATE SET name = excluded.name",
      [slug, name]
    )
  end

  def sport_slugs
    @db.execute("SELECT slug FROM sports ORDER BY slug").map { |row| row["slug"] }
  end

  def tv_row(event)
    [
      event[:ge_id].to_s,
      event[:sport],
      event[:sport_name],
      event[:title],
      event[:starts_at],
      event[:timed] ? 1 : 0,
      event[:competition],
      event[:watch_on],
      event[:note]
    ]
  end

  def hydrate_tv(row)
    {
      ge_id: row["ge_id"],
      sport: row["sport"],
      sport_name: row["sport_name"],
      title: row["title"],
      starts_at: row["starts_at"],
      timed: row["timed"] == 1,
      competition: row["competition"],
      watch_on: row["watch_on"],
      note: row["note"]
    }
  end

  def ensure_column(name)
    names = @db.execute("PRAGMA table_info(agenda_items)").map { |row| row["name"] }
    return if names.include?(name)

    @db.execute("ALTER TABLE agenda_items ADD COLUMN #{name} TEXT")
  end

  def hydrate(row)
    Item.new(
      id: row["id"],
      sport: row["sport"],
      title: row["title"],
      starts_on: Date.iso8601(row["starts_on"]),
      kicks_at: row["kicks_at"],
      note: row["note"],
      watch_on: row["watch_on"]
    )
  end

  def coerce_date(value)
    return value if value.is_a?(Date)
    return value.to_date if value.respond_to?(:to_date)

    Date.iso8601(value.to_s)
  end

  def blank_to_catalog_name(title, catalog)
    cleaned = title.to_s.strip
    cleaned.empty? ? catalog.name : cleaned
  end

  def blank_to_nil(value)
    cleaned = value.to_s.strip
    cleaned.empty? ? nil : cleaned
  end

  def sort_by_kickoff(items)
    items.sort_by { |item| [item.starts_on, item.kickoff_minutes, item.id] }
  end

  def require_item(id)
    item = find(id)
    return item if item

    raise NotFound, "item não encontrado: #{id.inspect}"
  end
end
