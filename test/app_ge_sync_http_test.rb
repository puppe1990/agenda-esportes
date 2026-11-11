# frozen_string_literal: true

require_relative "support/app_test_case"

class AppGeSyncHttpTest < AppTestCase
  def test_ge_sync_is_404_when_token_is_unset
    with_sync_token(nil) do
      get "/interno/ge-sync"
    end

    assert_equal 404, last_response.status
  end

  def test_ge_sync_is_401_with_the_wrong_bearer
    with_sync_token("segredo-certo") do
      header "Authorization", "Bearer outro"
      get "/interno/ge-sync"
    end

    assert_equal 401, last_response.status
  end

  def test_ge_sync_upserts_with_a_stub_client
    AgendaEsportes::App.ge_client = EmptyGeClient.new
    with_sync_token("segredo-certo") do
      header "Authorization", "Bearer segredo-certo"
      get "/interno/ge-sync"
    end

    assert_equal 200, last_response.status
    payload = JSON.parse(last_response.body)
    assert_equal true, payload["ok"]
    assert payload["from"]
    assert payload["to"]
    assert payload["synced_at"]
  end

  def test_ge_sync_is_502_when_ge_is_down
    AgendaEsportes::App.ge_client = DownGeClient.new
    with_sync_token("segredo-certo") do
      header "Authorization", "Bearer segredo-certo"
      get "/interno/ge-sync"
    end

    assert_equal 502, last_response.status
    payload = JSON.parse(last_response.body)
    assert_equal false, payload["ok"]
    assert payload["error"]
  end

  def test_home_does_not_lazy_sync_in_test
    AgendaEsportes::App.ge_client = DownGeClient.new
    get "/"

    assert last_response.ok?
  end
end
