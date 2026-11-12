# frozen_string_literal: true

require "net/http"
require "uri"

class UolClient
  URL = "https://www.uol.com.br/esporte/futebol/central-de-jogos"
  TIMEOUT = 8
  USER_AGENT = "Mozilla/5.0 (compatible; agenda-esportes/1.0; +https://agenda-esportes.sites.gestaobem.com)"

  class Error < StandardError; end

  def initialize(getter: nil)
    @getter = getter || method(:default_get)
  end

  def central_de_jogos
    attempts = 0
    begin
      attempts += 1
      @getter.call(URL, request_headers)
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

  def default_get(url, headers)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }
    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "UOL HTTP #{response.code}: #{response.body.to_s[0, 180]}"
    end

    response.body
  end
end
