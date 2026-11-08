# frozen_string_literal: true

require "bundler/setup"
require "sinatra/base"
require "rack/method_override"
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
    set :erb, escape_html: true
    use Rack::MethodOverride
    use Rack::Protection::AuthenticityToken

    FILTER_SLUG = {
      "futebol" => "fut",
      "automobilismo" => "auto"
    }.freeze

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

      def sport_filter(slug)
        FILTER_SLUG.fetch(slug, slug)
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

    get "/agenda" do
      erb :"agenda/index", locals: { items: store.all }
    end

    get "/agenda/:id/edit" do
      erb :"agenda/edit", locals: { item: find_item!, sports: SportsCatalog::ALL }
    end

    get "/agenda/:id" do
      erb :"agenda/show", locals: { item: find_item! }
    end

    post "/agenda" do
      day = parse_day(params[:day])
      store.add(sport: params[:sport], starts_at: day, title: params[:title])
      redirect "/?dia=#{day.iso8601}", 302
    rescue SportsCatalog::UnknownSport
      halt 422, "esporte desconhecido"
    end

    patch "/agenda/:id" do
      item = find_item!
      day = parse_day(params[:day])
      store.update(item.id, sport: params[:sport], starts_at: day, title: params[:title])
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
