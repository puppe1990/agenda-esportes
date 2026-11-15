# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

class GeClient
  ENDPOINT = "https://geql.globo.com/graphql"
  TIMEOUT = 8

  class Error < StandardError; end

  # Contestant is a union; popularName 422s on the union itself.
  CONTESTANT_FIELDS = <<~GRAPHQL.freeze
    ... on Team { popularName }
    ... on Athlete { popularName }
  GRAPHQL

  MATCH_INNER = <<~GRAPHQL.freeze
    match {
      id
      startDate
      startHour
      round
      firstContestant { #{CONTESTANT_FIELDS} }
      secondContestant { #{CONTESTANT_FIELDS} }
      phase { name }
      liveWatchSources { name }
    }
  GRAPHQL

  # AgendaItem is a union. `match` on the union 422s; so do id/startDate
  # on SoccerEvent. Wrap MATCH_INNER in the two concrete types.
  MATCH_FIELDS = <<~GRAPHQL.freeze
    ... on SoccerEvent { #{MATCH_INNER} }
    ... on MatchEventKind { #{MATCH_INNER} }
  GRAPHQL

  CHAMPIONSHIPS_FIELDS = <<~GRAPHQL.freeze
    championship { name url }
    now: items(filter: { moment: NOW }) { #{MATCH_FIELDS} }
    past: items(filter: { moment: PAST }) { #{MATCH_FIELDS} }
    future: items(filter: { moment: FUTURE }) { #{MATCH_FIELDS} }
  GRAPHQL

  MULTISPORT_FIELDS = <<~GRAPHQL.freeze
    sport { name code }
    championshipsAgenda {
      #{CHAMPIONSHIPS_FIELDS}
    }
  GRAPHQL

  def initialize(poster: nil)
    @poster = poster || method(:default_post)
  end

  # One handshake per day cost ~0.66s from fsn1 to Globo (fresh TCP+TLS
  # every request), so the 13-day window took 23s. Aliasing every day of
  # both roots into ONE document keeps the window at a single round trip.
  #
  # Both roots must share that document: geql answers a POST from a
  # PUBLIC-scoped HTTP cache (see extensions.cacheControl) and two
  # documents covering the same dates came back as the same payload —
  # multisportTabAgenda aliases were served championshipsAgenda rows, so
  # half the window silently vanished. One document has one response and
  # no cross-document cache to collide with.
  def agenda_range(dates)
    return {} if dates.empty?

    document = dates.each_with_index.map do |date, index|
      [
        "c#{index}: championshipsAgenda(filter: { date: \"#{date.iso8601}\" }) { #{CHAMPIONSHIPS_FIELDS} }",
        "m#{index}: multisportTabAgenda(filter: { date: \"#{date.iso8601}\" }) { #{MULTISPORT_FIELDS} }"
      ].join("\n")
    end
    data = post("query { #{document.join("\n")} }", {})["data"] || {}
    dates.each_with_index.to_h do |date, index|
      [
        date,
        {
          "championshipsAgenda" => { "data" => { "championshipsAgenda" => data["c#{index}"] } },
          "multisportTabAgenda" => { "data" => { "multisportTabAgenda" => data["m#{index}"] } }
        }
      ]
    end
  end

  private

  def post(query, variables)
    attempts = 0
    begin
      attempts += 1
      @poster.call(query, variables)
    rescue Error, Timeout::Error, SocketError, JSON::ParserError, Errno::ECONNREFUSED => e
      retry if attempts < 2

      raise Error, "geql retry exhausted after #{attempts} attempts: #{e.class}: #{e.message}"
    end
  end

  def default_post(query, variables)
    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    request = Net::HTTP::Post.new(uri)
    request["content-type"] = "application/json"
    request["apollographql-client-name"] = "agenda-esportes"
    request["origin"] = "https://ge.globo.com"
    request.body = JSON.generate(query: query, variables: variables)
    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "geql HTTP #{response.code}: #{response.body.to_s[0, 180]}"
    end

    JSON.parse(response.body)
  end
end
