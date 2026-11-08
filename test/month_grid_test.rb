# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/month_grid"

class MonthGridTest < Minitest::Test
  def test_november_2026_starts_on_sunday
    grid = MonthGrid.new(year: 2026, month: 11, marked: [])

    assert_equal Date.new(2026, 11, 1), grid.cells.first.date
    assert grid.cells.first.in_month
    assert_equal 7, grid.weekday_labels.size
    assert_equal "dom", grid.weekday_labels.first
  end

  def test_marks_days_that_have_agenda_items
    marked = [Date.new(2026, 11, 8)]
    grid = MonthGrid.new(year: 2026, month: 11, marked: marked)
    eighth = grid.cells.find { |cell| cell.date == Date.new(2026, 11, 8) }

    assert eighth.marked
    refute grid.cells.find { |cell| cell.date == Date.new(2026, 11, 9) }.marked
  end

  def test_pads_leading_and_trailing_days_outside_the_month
    grid = MonthGrid.new(year: 2026, month: 11, marked: [])

    assert_equal 0, grid.cells.size % 7
    assert grid.cells.last.date >= Date.new(2026, 11, 30)
  end
end
