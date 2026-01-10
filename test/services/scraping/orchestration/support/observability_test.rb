# frozen_string_literal: true

require "test_helper"

class Scraping::Orchestration::Support::ObservabilityTest < ActiveSupport::TestCase
  test "js_heavy_diagnosis returns not js-heavy when cleaned text exceeds threshold" do
    cleaned_html = "a" * (Scraping::Orchestration::Support::Observability::JS_HEAVY_TEXT_THRESHOLD + 10)
    html_content = "<html><body>#{cleaned_html}</body></html>"

    diagnosis = Scraping::Orchestration::Support::Observability.js_heavy_diagnosis(
      html_content: html_content,
      cleaned_html: cleaned_html
    )

    assert_equal false, diagnosis[:js_heavy]
    assert_equal "text_above_threshold", diagnosis[:reason]
    assert diagnosis[:text_length].to_i > Scraping::Orchestration::Support::Observability::JS_HEAVY_TEXT_THRESHOLD
  end

  test "js_heavy_diagnosis detects SPA marker even when cleaned text is low" do
    cleaned_html = "Loading..."
    html_content = "<html><head><script>var x='__NEXT_DATA__'</script></head><body></body></html>"

    diagnosis = Scraping::Orchestration::Support::Observability.js_heavy_diagnosis(
      html_content: html_content,
      cleaned_html: cleaned_html
    )

    assert_equal true, diagnosis[:js_heavy]
    assert_equal "spa_marker_detected", diagnosis[:reason]
    assert_includes diagnosis[:spa_markers_found], "__NEXT_DATA__"
  end

  test "js_heavy_diagnosis flags very low text without markers" do
    cleaned_html = "x" * 10
    html_content = "<html><body><div id=\"root\"></div></body></html>"

    diagnosis = Scraping::Orchestration::Support::Observability.js_heavy_diagnosis(
      html_content: html_content,
      cleaned_html: cleaned_html
    )

    assert_equal true, diagnosis[:js_heavy]
    assert_equal "spa_marker_detected", diagnosis[:reason]
  end

  test "js_heavy_page? matches js_heavy_diagnosis boolean" do
    cleaned_html = "x" * 10
    html_content = "<html><body><div id=\"root\"></div></body></html>"

    diagnosis = Scraping::Orchestration::Support::Observability.js_heavy_diagnosis(
      html_content: html_content,
      cleaned_html: cleaned_html
    )

    assert_equal diagnosis[:js_heavy],
      Scraping::Orchestration::Support::Observability.js_heavy_page?(
        html_content: html_content,
        cleaned_html: cleaned_html
      )
  end
end
