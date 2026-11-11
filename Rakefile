# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "."
  t.warning = false
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

namespace :ge do
  desc "Sync the GE TV grid (today + 6 days) into tv_events"
  task :sync do
    require "json"
    require_relative "lib/agenda_store"
    require_relative "lib/tv_grid"
    require_relative "lib/ge_sync"

    root = __dir__
    path = ENV.fetch("DATABASE_PATH") do
      File.join(ENV.fetch("CLEAT_DATA_DIR", File.join(root, "data")), "agenda.sqlite3")
    end
    store = AgendaStore.new(path)
    TvGrid.store = store
    result = GeSync.call(store: store)
    state = store.sync_state
    puts JSON.generate(result.merge(synced_at: state && state[:synced_at]))
  end
end
