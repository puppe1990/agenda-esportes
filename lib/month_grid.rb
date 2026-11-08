# frozen_string_literal: true

require "date"
require "set"

class MonthGrid
  Cell = Struct.new(:date, :in_month, :marked, keyword_init: true)
  WEEKDAYS = %w[dom seg ter qua qui sex sáb].freeze

  def initialize(year:, month:, marked: [])
    @year = year
    @month = month
    @marked = marked.map { |day| day.is_a?(Date) ? day : Date.parse(day.to_s) }.to_set
  end

  def weekday_labels
    WEEKDAYS
  end

  def cells
    first = Date.new(@year, @month, 1)
    last = Date.new(@year, @month, -1)
    start = first - first.wday
    finish = last + (6 - last.wday)

    (start..finish).map do |date|
      Cell.new(
        date: date,
        in_month: date.month == @month,
        marked: @marked.include?(date)
      )
    end
  end
end
