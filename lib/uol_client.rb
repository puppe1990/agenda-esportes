# frozen_string_literal: true

require "net/http"
require "uri"

class UolClient
  # Slash-less path 301s here; Net::HTTP does not follow redirects by default.
  URL = "https://www.uol.com.br/esporte/futebol/central-de-jogos/"
  TIMEOUT = 8
  MAX_REDIRECTS = 5
  USER_AGENT = "Mozilla/5.0 (compatible; agenda-esportes/1.0; +https://agenda-esportes.sites.gestaobem.com)"

  class Error < StandardError; end

  def initialize(getter: nil, url: URL)
    @url = url
    @getter = getter || method(:default_get)
  end

  def central_de_jogos
    attempts = 0
    begin
      attempts += 1
      @getter.call(@url, request_headers)
    rescue Error, Timeout::Error, SocketError, Errno::ECONNREFUSED => e
      retry if attempts < 2

      raise Error, "UOL retry exhausted after #{attempts} attempts: #{e.class}: #{e.message}"
    end
  end

  private

  def request_headers
    {
      "user-agent" => USER_AGENT,
      "origin" => "https://www.uol.com.br",
      "accept" => "text/html,application/xhtml+xml"
    }
  end

  def default_get(url, headers, hops: MAX_REDIRECTS)
    uri = URI(url)
    response = http_get(uri, headers)
    return follow_redirect(uri, response, headers, hops) if response.is_a?(Net::HTTPRedirection)
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "UOL HTTP #{response.code}: #{response.body.to_s[0, 180]}"
    end

    response.body
  end

  def http_get(uri, headers)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }
    http.request(request)
  end

  def follow_redirect(from_uri, response, headers, hops)
    location = response["location"].to_s
    next_uri = URI.join(from_uri, location) if hops.positive? && !location.empty?
    unless next_uri.is_a?(URI::HTTP)
      raise Error, "UOL HTTP #{response.code}: #{location.empty? ? response.body.to_s[0, 180] : location}"
    end

    default_get(next_uri.to_s, headers, hops: hops - 1)
  end
end
