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

    class << self
      attr_accessor :ge_client

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

    helpers do
      def store
        self.class.store
      end

      def asset_path(file)
        relative = file.delete_prefix("/")
        path = File.join(settings.public_folder, relative)
        stamp = File.exist?(path) ? File.mtime(path).to_i : 0
        "/#{relative}?v=#{stamp}"
      end

      def selected_day
        parsed = parse_query_date
        return parsed if parsed

        raw = params[:dia].to_s
        return Date.iso8601(raw) if raw.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Date.today
      end

      def day_path(date)
        "/?dia=#{date.day}&mes=#{date.month}&ano=#{date.year}"
      end

      def parse_query_date
        year = params[:ano].to_s
        month = params[:mes].to_s
        day = params[:dia].to_s
        return nil unless year.match?(/\A\d{4}\z/) && month.match?(/\A\d{1,2}\z/) && day.match?(/\A\d{1,2}\z/)

        y = year.to_i
        m = month.to_i
        d = day.to_i
        halt 400, "dia inválido" unless Date.valid_date?(y, m, d)

        Date.new(y, m, d)
      end

      def scoped_items
        if (day = parse_query_date)
          return store.items_on(day)
        end

        year = params[:ano].to_s
        month = params[:mes].to_s
        items = store.all
        if year.match?(/\A\d{4}\z/) && month.match?(/\A\d{1,2}\z/)
          y = year.to_i
          m = month.to_i
          return items.select { |item| item.starts_on.year == y && item.starts_on.month == m }
        end

        return items.select { |item| item.starts_on.year == year.to_i } if year.match?(/\A\d{4}\z/)

        items
      end

      def csrf_token
        session[:csrf]
      end

      def month_title(date)
        "#{MONTH_NAMES[date.month - 1]} #{date.year}"
      end

      def sport_name(slug)
        store.find_sport!(slug).name
      rescue SportsCatalog::UnknownSport
        slug.to_s
      end

      def find_item!
        item = store.find(params[:id])
        return item if item

        @not_found_message = "Esse item não está na agenda."
        halt 404
      end

      def parse_day(raw)
        Date.iso8601(raw.to_s)
      rescue ArgumentError, TypeError
        halt 400, "dia inválido"
      end

      def item_actions(item)
        erb :_item_actions, locals: { item: item }, layout: false
      end

      def saved_item(item)
        erb :_saved_item, locals: { item: item }, layout: false
      end

      def cal_event(game, day:, saved: nil)
        erb :_cal_event, locals: { game: game, day: day, saved: saved }, layout: false
      end

      def games_by_day
        TvGrid.grouped
      end

      def filter_sports
        seen = {}
        store.sports_in_tv_window.each { |sport| seen[sport.slug] = sport }
        store.all.each do |item|
          next if seen[item.sport]

          seen[item.sport] = begin
            store.find_sport!(item.sport)
          rescue SportsCatalog::UnknownSport
            SportsCatalog::Item.new(slug: item.sport, name: item.sport)
          end
        end
        seen.values.sort_by(&:slug)
      end

      def filter_css
        Array(@filter_sports).map do |sport|
          slug = sport.slug
          <<~CSS
            body:has(#f-#{slug}:checked) .bar label[for=f-#{slug}]{
              color:var(--accent);border-bottom-color:var(--accent);
            }
            body:has(#f-#{slug}:checked) .sport-pill[for=f-#{slug}]{
              background:var(--accent);
              color:var(--cta-fg);
            }
            body:has(#f-#{slug}:checked) .sport-pill[for=f-#{slug}] .sport-pill-count{
              background:rgba(11,18,16,.16);
              color:inherit;
            }
            body:has(#f-#{slug}:checked) .ev:not([data-s=#{slug}]),
            body:has(#f-#{slug}:checked) .game-card:not([data-s=#{slug}]),
            body:has(#f-#{slug}:checked) .cal-event:not([data-s=#{slug}]){display:none}
          CSS
        end.join
      end

      def ge_client
        self.class.ge_client || GeClient.new
      end

      def maybe_lazy_sync
        return if settings.test?
        return unless GeSync.stale?(store)

        Timeout.timeout(8) { GeSync.call(store: store, client: ge_client) }
      rescue GeSync::FetchError, Timeout::Error, GeClient::Error => error
        $stderr.puts "ge-sync lazy: #{error.class}: #{error.message}"
      end

      def bearer_token
        request.env["HTTP_AUTHORIZATION"].to_s[/\ABearer\s+(\S+)/, 1]
      end

      def run_ge_sync
        expected = ENV["GE_SYNC_TOKEN"].to_s
        halt 404 unless expected.bytesize.positive?
        halt 401 unless bearer_token == expected

        content_type :json
        result = GeSync.call(store: store, client: ge_client)
        state = store.sync_state
        JSON.generate(result.merge(synced_at: state && state[:synced_at]))
      rescue GeSync::FetchError => error
        content_type :json
        halt 502, JSON.generate({ ok: false, error: error.message })
      end

      def week_strip_for(day)
        monday = day - (day.cwday - 1)
        counts = (0..6).each_with_object({}) do |offset, hash|
          date = monday + offset
          hash[date] = TvGrid.on(date).size
        end
        WeekStrip.new(day: day, counts: counts)
      end

      def sport_counts(games)
        games.each_with_object(Hash.new(0)) { |game, hash| hash[game.sport] += 1 }
      end

      def week_count_label(cell)
        cell.selected ? "#{cell.count} jogos" : "#{cell.count} jgs"
      end

      def saved_lookup
        store.all.each_with_object({}) do |item, hash|
          hash[[item.starts_on, item.title]] = item
        end
      end

      def fill_saved_broadcasts
        store.all.each do |item|
          next unless item.kicks_at.to_s.strip.empty?

          game = TvGrid.on(item.starts_on).find { |candidate| candidate.title == item.title }
          next unless game

          store.update(
            item.id,
            sport: item.sport,
            starts_at: item.starts_on,
            title: item.title,
            kicks_at: game.clock,
            note: game.note,
            watch_on: game.where
          )
        end
      end
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
      halt 422, "esporte desconhecido"
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
      halt 422, "esporte desconhecido"
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
