# frozen_string_literal: true

require "time"

class TvGrid
  class << self
    attr_accessor :store
  end

  MONTH_ABBR = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze

  Event = Struct.new(:sport, :title, :starts_at, :competition, :timed, :where, :note, keyword_init: true) do
    def clock
      return "#{starts_at.day} #{MONTH_ABBR[starts_at.month - 1]}" unless timed

      min = starts_at.min
      return "#{starts_at.hour}h" if min.zero?

      "#{starts_at.hour}h#{min.to_s.rjust(2, '0')}"
    end
  end

  def self.on(day)
    return [] unless store

    store.tv_events_on(day).map { |row| event_from(row) }
  end

  def self.grouped
    return {} unless store

    store.tv_events_grouped.transform_values { |rows| rows.map { |row| event_from(row) } }
  end

  def self.event_from(row)
    Event.new(
      sport: row[:sport],
      title: row[:title],
      starts_at: Time.parse(row[:starts_at]),
      competition: row[:competition],
      timed: row[:timed],
      where: row[:watch_on].to_s,
      note: row[:note].to_s
    )
  end
  private_class_method :event_from
end
