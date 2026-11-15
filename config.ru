# frozen_string_literal: true

require_relative "app"

SyncScheduler.start(store: AgendaEsportes::App.store) unless ENV["RACK_ENV"] == "test"

run AgendaEsportes::App
