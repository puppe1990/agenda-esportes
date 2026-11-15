# frozen_string_literal: true

require_relative "ge_sync"

# The GitHub schedule (0 9 * * *) drifts 6-8h behind on this repo, so the
# snapshot kept passing STALE_AFTER while the next run was still queued.
# The fetch is a single GraphQL document now, so the app tops itself up
# without waiting on a scheduler. Requests never block on it: they only
# check GeSync.due? and hand off to refresh_async.
module SyncScheduler
  INTERVAL = 15 * 60

  def self.start(store:, interval: INTERVAL, logger: $stderr)
    Thread.new do
      loop do
        refresh(store: store, logger: logger)
        sleep interval
      end
    end
  end

  def self.refresh(store:, logger: $stderr)
    return unless GeSync.due?(store)

    GeSync.refresh_async(store: store)
  rescue StandardError => error
    logger.puts "sync scheduler: #{error.class}: #{error.message}"
  end
end
