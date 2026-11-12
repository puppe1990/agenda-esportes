# frozen_string_literal: true

require "date"
require "set"
require_relative "ge_client"
require_relative "ge_parser"
require_relative "uol_client"
require_relative "uol_parser"

class GeSync
  STALE_AFTER = 20 * 60 * 60
  MUTEX = Mutex.new

  class FetchError < StandardError; end

  def self.call(store:, client: GeClient.new, uol_client: nil, now: Time.now)
    MUTEX.synchronize { new(store: store, client: client, uol_client: uol_client, now: now).run }
  end

  def self.stale?(store, now: Time.now)
    state = store.sync_state
    return true if state.nil?

    Time.parse(state[:synced_at]) < (now - STALE_AFTER)
  end

  def initialize(store:, client:, now:, uol_client: nil)
    @store = store
    @client = client
    @uol_client = uol_client
    @now = now
  end

  def run
    from, to = tv_window
    ge_events, succeeded, errors = fetch_ge(from, to)
    raise_if_ge_blank(succeeded, errors)

    uol_ok, uol_events, uol_error = fetch_uol(from, to)
    errors << uol_error if uol_error
    extra = reject_duplicate_matchups(uol_events, ge_events)
    merged = ge_events + extra
    persist(merged, from: from, to: to, prune_dates: succeeded, keep_uol: !uol_ok, errors: errors)
    { ok: true, from: from.iso8601, to: to.iso8601, upserted: merged.size, uol: extra.size, deleted: 0 }
  end

  private

  # Week strip is Monday–Sunday. Starting at today left Mon/Tue of the
  # current week with 0 jogos and sport-name cards instead of matchups.
  def tv_window
    today = @now.to_date
    monday = today - (today.cwday - 1)
    [monday, today + 6]
  end

  def fetch_ge(from, to)
    events = []
    succeeded = []
    errors = []
    (from..to).each do |date|
      events.concat(fetch_date(date))
      succeeded << date
    rescue GeClient::Error => e
      errors << "#{date.iso8601}: #{e.message}"
    end
    [events, succeeded, errors]
  end

  def fetch_date(date)
    GeParser.parse(@client.championships_agenda(date)) +
      GeParser.parse(@client.multisport_agenda(date))
  end

  def fetch_uol(from, to)
    return [false, [], nil] unless @uol_client

    parsed = UolParser.parse(@uol_client.central_de_jogos)
    kept = parsed.select { |event| in_window?(event, from, to) }
    [true, kept, nil]
  rescue UolClient::Error, UolParser::Error => e
    [false, [], "uol: #{e.message}"]
  end

  def in_window?(event, from, to)
    day = Date.iso8601(event[:starts_at].to_s[0, 10])
    day >= from && day <= to
  end

  def reject_duplicate_matchups(uol_events, ge_events)
    seen = ge_events.map { |event| matchup_key(event) }.to_set
    uol_events.reject { |event| seen.include?(matchup_key(event)) }
  end

  def matchup_key(event)
    [event[:starts_at].to_s[0, 10], event[:title].to_s.downcase.strip]
  end

  def raise_if_ge_blank(succeeded, errors)
    return unless succeeded.empty?

    @store.record_sync!(
      synced_at: @now,
      event_count: @store.tv_events_grouped.values.flatten.size,
      error: errors.join("; ")
    )
    raise FetchError, "geql falhou em todos os dias: #{errors.join('; ')}"
  end

  def persist(events, from:, to:, prune_dates:, keep_uol:, errors:)
    prefixes = keep_uol ? [UolParser::ID_PREFIX] : []
    @store.replace_tv_window(events, from: from, to: to, prune_dates: prune_dates, keep_id_prefixes: prefixes)
    @store.record_sync!(
      synced_at: @now,
      event_count: events.size,
      error: errors.empty? ? nil : errors.join("; ")
    )
  end
end
