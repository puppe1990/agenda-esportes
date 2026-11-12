# frozen_string_literal: true

require "bundler/setup"
require "sinatra/base"
require "rack/method_override"
require "rack/protection"
require "date"
require "fileutils"
require "json"
require "timeout"
require_relative "lib/sports_catalog"
require_relative "lib/agenda_store"
require_relative "lib/month_grid"
require_relative "lib/week_strip"
require_relative "lib/tv_grid"
require_relative "lib/ge_client"
require_relative "lib/ge_sync"
require_relative "lib/uol_client"
require_relative "lib/app_helpers"

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
    set :erb, escape_html: true
    use Rack::MethodOverride
    use Rack::Protection::AuthenticityToken
    helpers AppHelpers

    class << self
      attr_accessor :ge_client, :uol_client

      def store=(value)
        @store = value
        TvGrid.store = value
      end

      def store
        @store ||= begin
          value = AgendaStore.new(database_path)
          TvGrid.store = value
          value
        end
      end

      def database_path
        ENV.fetch("DATABASE_PATH") do
          File.join(ENV.fetch("CLEAT_DATA_DIR", File.join(root, "data")), "agenda.sqlite3")
        end
      end
    end

    before do
      @show_bar_filters = true
      maybe_lazy_sync if request.get? && request.path_info == "/"
      fill_saved_broadcasts
      @filter_sports = filter_sports
    end

    get "/" do
      @show_bar_filters = false
      day = selected_day
      marked = store.days_with_items(day.year, day.month)
      games = TvGrid.on(day)
      erb :index, locals: {
        day: day,
        items: store.all,
        on_day: store.items_on(day),
        games: games,
        grid: MonthGrid.new(year: day.year, month: day.month, marked: marked),
        week: week_strip_for(day),
        day_sport_counts: sport_counts(games),
        sports: store.sports_in_tv_window,
        month_games: games_by_day,
        saved_by_title: saved_lookup
      }
    end

    # Cron cannot POST a CSRF token. GET and POST share run_ge_sync + Bearer.
    get "/interno/ge-sync" do
      run_ge_sync
    end

    post "/interno/ge-sync" do
      run_ge_sync
    end

    get "/agenda" do
      erb :"agenda/index", locals: { items: scoped_items }
    end

    get "/agenda/:id/edit" do
      erb :"agenda/edit", locals: { item: find_item!, sports: store.sports }
    end

    get "/agenda/:id" do
      erb :"agenda/show", locals: { item: find_item! }
    end

    post "/agenda" do
      day = parse_day(params[:day])
      store.add(
        sport: params[:sport],
        starts_at: day,
        title: params[:title],
        kicks_at: params[:kicks_at],
        note: params[:note],
        watch_on: params[:watch]
      )
      redirect day_path(day), 302
    rescue SportsCatalog::UnknownSport
      halt 422, "esporte desconhecido: #{params[:sport].inspect}"
    end

    patch "/agenda/:id" do
      item = find_item!
      day = parse_day(params[:day])
      store.update(
        item.id,
        sport: params[:sport],
        starts_at: day,
        title: params[:title],
        kicks_at: params[:kicks_at],
        note: params[:note],
        watch_on: params[:watch]
      )
      redirect "/agenda/#{item.id}", 302
    rescue SportsCatalog::UnknownSport
      halt 422, "esporte desconhecido: #{params[:sport].inspect}"
    end

    delete "/agenda/:id" do
      item = find_item!
      store.delete(item.id)
      redirect "/agenda", 302
    end

    not_found do
      erb :not_found, locals: { message: @not_found_message || "Essa página não existe." }
    end
  end
end
