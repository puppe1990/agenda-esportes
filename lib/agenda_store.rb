# frozen_string_literal: true

require "sqlite3"
require "date"
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
    catalog = SportsCatalog.find!(sport)
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
    catalog = SportsCatalog.find!(sport)
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
