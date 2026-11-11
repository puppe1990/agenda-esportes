# frozen_string_literal: true

require_relative "support/app_test_case"

class AppChromeTest < AppTestCase
  def test_system_uses_dark_mint_tokens
    css = File.read(File.expand_path("../public/app.css", __dir__))

    assert_match(/--accent:\s*#6eff94/i, css)
    refute_match(/--accent:\s*#c8f542/, css)
    get "/?dia=8&mes=11&ano=2026"
    refute_includes last_response.body, 'data-theme="paper"'
    get "/agenda"
    refute_includes last_response.body, 'data-theme="paper"'
  end

  def test_home_stylesheet_is_cache_busted
    get "/"

    assert_match(%r{href="/app\.css\?v=\d+"}, last_response.body)
  end

  def test_home_open_graph_card_is_wired
    get "/"

    assert_includes last_response.body, 'property="og:image" content="https://agenda-esportes.sites.gestaobem.com/og.png"'
    assert_includes last_response.body, 'property="og:image:width" content="1200"'
    assert_includes last_response.body, 'property="og:image:height" content="630"'
    assert_includes last_response.body, 'property="og:image:type" content="image/png"'
    assert_includes last_response.body, 'name="twitter:card" content="summary_large_image"'
    assert_includes last_response.body, 'name="twitter:image" content="https://agenda-esportes.sites.gestaobem.com/og.png"'
  end

  def test_og_html_is_a_dark_mint_week_strip_card
    html = File.read(File.expand_path("../public/og.html", __dir__))

    assert_includes html, "1200px"
    assert_includes html, "630px"
    assert_includes html, "#6eff94"
    assert_includes html, "#0b0e14"
    assert_includes html, "id=\"og\""
    assert_match(/Agenda de esportes/i, html)
    assert_includes html, "Automobilismo"
    refute_match(/tênis|tenis|esports|e-sports|corrida/i, html)
  end

  def test_og_png_is_1200_by_630
    path = File.expand_path("../public/og.png", __dir__)

    assert File.file?(path), "public/og.png missing — render public/og.html"
    header = File.binread(path, 24)
    assert_equal [1200, 630], header[16, 8].unpack("NN")
  end
end
