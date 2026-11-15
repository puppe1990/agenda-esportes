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
  # Guards the in-flight flag, not the fetch itself: MUTEX is held by the
  # background thread for the whole run, so try_lock there would deadlock
  # the next caller and unlock from another thread raises.
  STATE = Mutex.new
  # A stale snapshot used to re-run the whole fetch inside every GET /.
  # Background syncs keep the request on the stored snapshot and this
  # guard stops a burst of requests from stacking identical runs.
  RETRY_AFTER = 10 * 60

  class FetchError < StandardError; end

  def self.call(store:, client: GeClient.new, uol_client: nil, now: Time.now)
    MUTEX.synchronize { new(store: store, client: client, uol_client: uol_client, now: now).run }
  end

  def self.stale?(store, now: Time.now)
    state = store.sync_state
    return true if state.nil?

    Time.parse(state[:synced_at]) < (now - STALE_AFTER)
  end

  # An in-flight run already covers the staleness; a recent failure waits
  # RETRY_AFTER so a dead upstream is not re-hit on every page load.
  def self.due?(store, now: Time.now)
    return false if running?

    state = store.sync_state
    return true if state.nil?

    synced_at = Time.parse(state[:synced_at])
    return true if synced_at < (now - STALE_AFTER)

    failed_at = state[:error].to_s.empty? ? nil : synced_at
    !failed_at.nil? && failed_at < (now - RETRY_AFTER)
  end

  def self.running?
    STATE.synchronize { @running }
  end

  # Tests drive refresh_async directly; clearing the flag keeps a blocked
  # fake from leaking state into the next test.
  def self.reset_running!
    STATE.synchronize { @running = false }
  end

  def self.refresh_async(store:, client: nil, uol_client: nil)
    claimed = STATE.synchronize do
      next false if @running

      @running = true
    end
    return false unless claimed

    Thread.new do
      call(store: store, client: client || GeClient.new, uol_client: uol_client || UolClient.new)
    rescue StandardError => error
      $stderr.puts "ge-sync background: #{error.class}: #{error.message}"
    ensure
      STATE.synchronize { @running = false }
    end
    true
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

  # One document covers both roots, so the window is a single handshake.
  # A failed day only nulls its own aliases, so a blank slice marks that
  # date as unsynced (its rows survive the prune) instead of failing the run.
  def fetch_ge(from, to)
    dates = (from..to).to_a
    slices = @client.agenda_range(dates)
    events = dates.flat_map { |date| parse_day(slices[date]) }
    succeeded = dates.select { |date| slices[date] }
    [events, succeeded, []]
  rescue GeClient::Error => e
    [[], [], ["#{from.iso8601}..#{to.iso8601}: #{e.message}"]]
  end

  def parse_day(slice)
    return [] if slice.nil?

    GeParser.parse(slice["championshipsAgenda"] || {}) +
      GeParser.parse(slice["multisportTabAgenda"] || {})
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
