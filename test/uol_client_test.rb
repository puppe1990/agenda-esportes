# frozen_string_literal: true

require "socket"

require_relative "test_helper"
require_relative "../lib/uol_client"

class UolClientTest < Minitest::Test
  def test_canonical_url_has_the_trailing_slash_uol_301s_to
    assert_equal "https://www.uol.com.br/esporte/futebol/central-de-jogos/", UolClient::URL
  end

  def test_follows_http_301_to_the_html_body
    html = "<html>#{Faker::Lorem.word}</html>"
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    thread = Thread.new { serve_redirect_then_html(server, port, html) }

    body = UolClient.new(url: "http://127.0.0.1:#{port}/from").central_de_jogos

    assert_equal html, body
  ensure
    thread&.kill
    server&.close
  end

  def test_gets_central_de_jogos_with_a_browser_user_agent
    fetched = []
    html = "<html>#{Faker::Lorem.word}</html>"
    getter = lambda do |url, headers|
      fetched << [url, headers]
      html
    end

    body = UolClient.new(getter: getter).central_de_jogos

    assert_equal 1, fetched.size
    assert_equal UolClient::URL, fetched[0][0]
    assert_match(%r{\AMozilla/5\.0}, fetched[0][1]["user-agent"])
    assert_equal "https://www.uol.com.br", fetched[0][1]["origin"]
    assert_equal html, body
  end

  def test_retries_once_then_raises
    attempts = 0
    getter = lambda do |_url, _headers|
      attempts += 1
      raise Timeout::Error, "read timeout"
    end

    error = assert_raises(UolClient::Error) do
      UolClient.new(getter: getter).central_de_jogos
    end

    assert_equal 2, attempts
    assert_match(/timeout/i, error.message)
    assert_includes error.message, "2"
  end

  def test_http_error_includes_status
    getter = lambda do |_url, _headers|
      raise UolClient::Error, "UOL HTTP 503: behind"
    end

    error = assert_raises(UolClient::Error) do
      UolClient.new(getter: getter).central_de_jogos
    end

    assert_match(/503/, error.message)
  end

  private

  def serve_redirect_then_html(server, port, html)
    2.times do
      socket = server.accept
      request = +""
      while (line = socket.gets)
        request << line
        break if line == "\r\n"
      end
      if request.start_with?("GET /from")
        socket.write "HTTP/1.1 301 Moved Permanently\r\nLocation: http://127.0.0.1:#{port}/to\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
      else
        socket.write "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{html.bytesize}\r\nConnection: close\r\n\r\n#{html}"
      end
      socket.close
    end
  end
end
