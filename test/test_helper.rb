# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["TZ"] ||= "America/Sao_Paulo"
ENV["SESSION_SECRET"] ||= "agenda-esportes-test-secret-must-be-at-least-64-bytes-long!!!!!!"

require "bundler/setup"
require "minitest/autorun"
require "faker"
require "fileutils"
require "tmpdir"
require "date"

Faker::Config.locale = "pt-BR"
