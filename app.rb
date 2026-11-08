# frozen_string_literal: true

require "bundler/setup"
require "sinatra/base"
require "rack/protection"
require "date"
require "fileutils"
require_relative "lib/sports_catalog"
require_relative "lib/agenda_store"
require_relative "lib/month_grid"

module AgendaEsportes
  class App < Sinatra::Base
    MONTH_NAMES = %w[
      janeiro fevereiro março abril maio junho
      julho agosto setembro outubro novembro dezembro
    ].freeze

    set :root, File.expand_path(__dir__)
    set :views, File.join(root, "views")
    set :public_folder, File.join(root, "public")
    set :sessions, secret: ENV.fetch("SESSION_SECRET") { "agenda-esportes-dev-secret-change-me-in-production-64-bytes-min!" }
    use Rack::Protection::AuthenticityToken

    class << self
      attr_writer :store

      def store
        @store ||= AgendaStore.new(database_path)
      end

      def database_path
        ENV.fetch("DATABASE_PATH") do
          File.join(ENV.fetch("CLEAT_DATA_DIR", File.join(root, "data")), "agenda.sqlite3")
        end
      end
    end

    helpers do
      def store
        self.class.store
      end

      def selected_day
        raw = params[:dia].to_s
        return Date.iso8601(raw) if raw.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Date.today
      end

      def csrf_token
        session[:csrf]
      end

      def month_title(date)
        "#{MONTH_NAMES[date.month - 1]} #{date.year}"
      end

      def sport_name(slug)
        SportsCatalog.find!(slug).name
      rescue SportsCatalog::UnknownSport
        slug.to_s
      end
    end

    get "/" do
      day = selected_day
      marked = store.days_with_items(day.year, day.month)
      erb :index, locals: {
        day: day,
        items: store.all,
        on_day: store.items_on(day),
        grid: MonthGrid.new(year: day.year, month: day.month, marked: marked),
        sports: SportsCatalog::ALL
      }
    end

    post "/agenda" do
      day = Date.iso8601(params[:day].to_s)
      store.add(sport: params[:sport], starts_at: day, title: params[:title])
      redirect "/?dia=#{day.iso8601}", 302
    rescue SportsCatalog::UnknownSport
      halt 422, "esporte desconhecido"
    rescue ArgumentError
      halt 400, "dia inválido"
    end
  end
end
