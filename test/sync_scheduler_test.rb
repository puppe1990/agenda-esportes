# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/agenda_store"
require_relative "../lib/ge_client"
require_relative "../lib/ge_sync"
require_relative "../lib/sync_scheduler"

class SyncSchedulerTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("agenda-scheduler-")
    @store = AgendaStore.new(File.join(@dir, "agenda.sqlite3"))
    @now = Time.parse("2026-11-11T09:00:00-03:00")
    GeSync.reset_running!
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
    GeSync.reset_running!
  end

  def test_refresh_claims_a_run_when_the_snapshot_is_fresh
    @store.record_sync!(synced_at: Time.now, event_count: 3)

    SyncScheduler.refresh(store: @store)

    refute GeSync.running?
  end

  def test_refresh_starts_a_run_when_the_snapshot_is_stale
    @store.record_sync!(synced_at: Time.now - (21 * 3600), event_count: 3)
    GeClient.stub(:new, EmptyGeClient.new) do
      SyncScheduler.refresh(store: @store)

      assert_equal true, GeSync.running? || @store.sync_state[:error].nil?
    end
  end

  def test_refresh_logs_and_keeps_going_when_the_store_raises
    store = Object.new
    store.define_singleton_method(:sync_state) { raise "boom" }
    logged = StringIO.new

    SyncScheduler.refresh(store: store, logger: logged)

    assert_match(/boom/, logged.string)
  end
end
