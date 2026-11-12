# frozen_string_literal: true

require_relative "../test_helper"
require "rack/test"
require "json"

ENV["DATABASE_PATH"] ||= File.join(Dir.mktmpdir("agenda-esportes-app-"), "agenda.sqlite3")

require_relative "../../app"
require_relative "ge_fakes"
require_relative "uol_fakes"

class AppTestCase < Minitest::Test
  include Rack::Test::Methods

  def app
    AgendaEsportes::App
  end

  def setup
    path = ENV.fetch("DATABASE_PATH")
    FileUtils.rm_f(path)
    AgendaEsportes::App.store = AgendaStore.new(path)
    AgendaEsportes::App.ge_client = nil if AgendaEsportes::App.respond_to?(:ge_client=)
    AgendaEsportes::App.uol_client = EmptyUolClient.new if AgendaEsportes::App.respond_to?(:uol_client=)
  end

  def csrf_token
    get "/"
    last_response.body[/name="authenticity_token"\s+value="([^"]+)"/, 1] ||
      last_response.body[/value="([^"]+)"\s+name="authenticity_token"/, 1] ||
      last_response.body[/name="csrf-token" content="([^"]+)"/, 1]
  end

  def seed_tv(*events, **single)
    events = [single] if events.empty?
    rows = events.each_with_index.map do |event, index|
      {
        ge_id: "ge-#{index + 1}",
        sport: "futebol",
        sport_name: "Futebol",
        title: "#{Faker::Sports::Football.team} x #{Faker::Sports::Football.team}",
        starts_at: "2026-11-08T17:00:00-03:00",
        timed: true,
        competition: "Liga",
        watch_on: "Globo",
        note: "Liga · pênaltis"
      }.merge(event)
    end
    from = rows.map { |row| Date.iso8601(row[:starts_at][0, 10]) }.min
    AgendaEsportes::App.store.replace_tv_window(rows, from: from, to: from + 6)
    rows
  end

  def with_sync_token(token)
    previous = ENV["GE_SYNC_TOKEN"]
    if token.nil?
      ENV.delete("GE_SYNC_TOKEN")
    else
      ENV["GE_SYNC_TOKEN"] = token
    end
    yield
  ensure
    if previous.nil?
      ENV.delete("GE_SYNC_TOKEN")
    else
      ENV["GE_SYNC_TOKEN"] = previous
    end
  end
end
