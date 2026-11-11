# frozen_string_literal: true

module AgendaEsportes
  module AppHelpers
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
      halt 400, "dia inválido: recebido #{year}-#{month}-#{day}" unless Date.valid_date?(y, m, d)

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
      "#{AgendaEsportes::App::MONTH_NAMES[date.month - 1]} #{date.year}"
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
      halt 400, "dia inválido: recebido #{raw.inspect}, esperado ISO YYYY-MM-DD"
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

    # Tilt ERB rejects <%== %>. escape_html would encode quotes in the
    # selectors, so rules omit them: [data-s=#{slug}] not [data-s="slug"].
    def filter_css
      Array(@filter_sports).map { |sport| filter_css_for(sport.slug) }.join
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

    private

    def filter_css_for(slug)
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
    end
  end
end
