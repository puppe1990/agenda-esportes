# frozen_string_literal: true

port ENV.fetch("PORT", 4567)
bind "tcp://0.0.0.0"
workers Integer(ENV.fetch("WEB_CONCURRENCY", 0))
threads 1, Integer(ENV.fetch("PUMA_MAX_THREADS", 4))
environment ENV.fetch("RACK_ENV", "production")
