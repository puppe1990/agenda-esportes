# frozen_string_literal: true

require "sqlite3"
require "date"
require "fileutils"
require_relative "sports_catalog"

class AgendaStore
  Item = Struct.new(:id, :sport, :title, :starts_on, keyword_init: true)

  def initialize(path)
    FileUtils.mkdir_p(File.dirname(path))
    @db = SQLite3::Database.new(path)
    @db.results_as_hash = true
    @db.execute("PRAGMA foreign_keys = ON")
    migrate
  end

  def add(sport:, starts_at:, title: nil)
    catalog = SportsCatalog.find!(sport)
    cleaned = title.to_s.strip
    cleaned = catalog.name if cleaned.empty?
    day = coerce_date(starts_at)

    @db.execute(
      "INSERT INTO agenda_items (sport, title, starts_on) VALUES (?, ?, ?)",
      [catalog.slug, cleaned, day.iso8601]
    )

    find(@db.last_insert_row_id)
  end

  def all
    @db.execute("SELECT * FROM agenda_items ORDER BY starts_on ASC, id ASC").map { |row| hydrate(row) }
  end

  def items_on(day)
    date = coerce_date(day)
    @db.execute(
      "SELECT * FROM agenda_items WHERE starts_on = ? ORDER BY id ASC",
      [date.iso8601]
    ).map { |row| hydrate(row) }
  end

  def days_with_items(year, month)
    start = Date.new(year, month, 1)
    stop = Date.new(year, month, -1)
    @db.execute(
      "SELECT DISTINCT starts_on FROM agenda_items WHERE starts_on >= ? AND starts_on <= ? ORDER BY starts_on",
      [start.iso8601, stop.iso8601]
    ).map { |row| Date.iso8601(row["starts_on"]) }
  end

  def delete(id)
    @db.execute("DELETE FROM agenda_items WHERE id = ?", [Integer(id)])
  end

  def find(id)
    row = @db.get_first_row("SELECT * FROM agenda_items WHERE id = ?", [Integer(id)])
    hydrate(row) if row
  end

  private

  def migrate
    @db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS agenda_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sport TEXT NOT NULL,
        title TEXT NOT NULL,
        starts_on TEXT NOT NULL
      )
    SQL
  end

  def hydrate(row)
    Item.new(
      id: row["id"],
      sport: row["sport"],
      title: row["title"],
      starts_on: Date.iso8601(row["starts_on"])
    )
  end

  def coerce_date(value)
    return value if value.is_a?(Date)
    return value.to_date if value.respond_to?(:to_date)

    Date.iso8601(value.to_s)
  end
end
