# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/uol_client"

class UolClientTest < Minitest::Test
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
end
