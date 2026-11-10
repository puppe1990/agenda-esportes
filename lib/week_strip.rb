# frozen_string_literal: true

require "date"

class WeekStrip
  LABELS = %w[seg ter qua qui sex sáb dom].freeze

  Day = Struct.new(:date, :label, :today, :selected, :saturday, :count, keyword_init: true)

  def initialize(day:, today: Date.today, counts: {})
    @day = day
    @today = today
    @counts = counts
  end

  def days
    monday = @day - (@day.cwday - 1)
    (0..6).map do |offset|
      date = monday + offset
      Day.new(
        date: date,
        label: date == @today ? "hoje" : LABELS[offset],
        today: date == @today,
        selected: date == @day,
        saturday: date.saturday?,
        count: Integer(@counts.fetch(date, 0))
      )
    end
  end

  def prev_week
    @day - 7
  end

  def next_week
    @day + 7
  end
end
