# frozen_string_literal: true

require "date"
require_relative "ge_client"
require_relative "ge_parser"

class GeSync
  STALE_AFTER = 20 * 60 * 60
  MUTEX = Mutex.new

  class FetchError < StandardError; end

  def self.call(store:, client: GeClient.new, now: Time.now)
    MUTEX.synchronize { new(store: store, client: client, now: now).run }
  end

  def self.stale?(store, now: Time.now)
    state = store.sync_state
    return true if state.nil?

    Time.parse(state[:synced_at]) < (now - STALE_AFTER)
  end

  def initialize(store:, client:, now:)
    @store = store
    @client = client
    @now = now
  end

  def run
    from, to = tv_window
    events = []
    succeeded = []
    errors = []

    (from..to).each do |date|
      events.concat(fetch_date(date))
      succeeded << date
    rescue GeClient::Error => e
      errors << "#{date.iso8601}: #{e.message}"
    end

    if succeeded.empty?
      @store.record_sync!(synced_at: @now, event_count: @store.tv_events_grouped.values.flatten.size, error: errors.join("; "))
      raise FetchError, "geql falhou em todos os dias: #{errors.join('; ')}"
    end

    @store.replace_tv_window(events, from: from, to: to, prune_dates: succeeded)
    @store.record_sync!(synced_at: @now, event_count: events.size, error: errors.empty? ? nil : errors.join("; "))
    { ok: true, from: from.iso8601, to: to.iso8601, upserted: events.size, deleted: 0 }
  end

  private

  # Week strip is Monday–Sunday. Starting at today left Mon/Tue of the
  # current week with 0 jogos and sport-name cards instead of matchups.
  def tv_window
    today = @now.to_date
    monday = today - (today.cwday - 1)
    [monday, today + 6]
  end

  def fetch_date(date)
    GeParser.parse(@client.championships_agenda(date)) +
      GeParser.parse(@client.multisport_agenda(date))
  end
end
