# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/week_strip"

class WeekStripTest < Minitest::Test
  def test_week_of_a_sunday_runs_monday_to_sunday
    strip = WeekStrip.new(day: Date.new(2026, 11, 8), today: Date.new(2026, 11, 10))

    dates = strip.days.map(&:date)

    assert_equal Date.new(2026, 11, 2), dates.first
    assert_equal Date.new(2026, 11, 8), dates.last
    assert_equal 7, dates.size
    assert_equal %w[seg ter qua qui sex sáb dom], strip.days.map(&:label)
  end

  def test_marks_the_selected_day_and_saturday
    strip = WeekStrip.new(day: Date.new(2026, 11, 7), today: Date.new(2026, 11, 10))
    saturday = strip.days.find { |cell| cell.date == Date.new(2026, 11, 7) }
    friday = strip.days.find { |cell| cell.date == Date.new(2026, 11, 6) }

    assert saturday.selected
    assert saturday.saturday
    refute friday.selected
    refute friday.saturday
  end

  def test_labels_today_as_hoje
    strip = WeekStrip.new(day: Date.new(2026, 11, 4), today: Date.new(2026, 11, 4))
    today = strip.days.find(&:today)

    assert_equal Date.new(2026, 11, 4), today.date
    assert_equal "hoje", today.label
    assert today.selected
  end

  def test_uses_counts_per_day
    counts = { Date.new(2026, 11, 8) => 18, Date.new(2026, 11, 2) => 3 }
    strip = WeekStrip.new(day: Date.new(2026, 11, 8), today: Date.new(2026, 11, 10), counts: counts)

    assert_equal 18, strip.days.last.count
    assert_equal 3, strip.days.first.count
    assert_equal 0, strip.days[1].count
  end

  def test_shifts_a_whole_week
    strip = WeekStrip.new(day: Date.new(2026, 11, 8), today: Date.new(2026, 11, 10))

    assert_equal Date.new(2026, 11, 1), strip.prev_week
    assert_equal Date.new(2026, 11, 15), strip.next_week
  end
end
