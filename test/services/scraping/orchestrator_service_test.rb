# frozen_string_literal: true

require "test_helper"

module Scraping
  class OrchestratorServiceTest < ActiveSupport::TestCase
    test "js_heavy_page? returns true for small text with SPA markers" do
      html = "<html><script>/* app */</script><div id=\"root\"></div></html>"
      cleaned = "Hi"

      assert_equal true, Scraping::Orchestration::Support::Observability.js_heavy_page?(html_content: html, cleaned_html: cleaned)
    end

    test "js_heavy_page? returns false for sufficiently large cleaned text" do
      html = "<html><body><h1>Title</h1></body></html>"
      cleaned = "a" * 2000

      assert_equal false, Scraping::Orchestration::Support::Observability.js_heavy_page?(html_content: html, cleaned_html: cleaned)
    end

    test "selectors extraction creates an HtmlScrapingLog row" do
      job_listing = create(:job_listing, url: "https://boards.greenhouse.io/acme/jobs/123")
      attempt = create(:scraping_attempt, job_listing: job_listing, url: job_listing.url, domain: "boards.greenhouse.io")
      event_recorder = Scraping::EventRecorderService.new(attempt, job_listing: job_listing)
      context = Scraping::Orchestration::Context.new(job_listing: job_listing, attempt: attempt, event_recorder: event_recorder)

      selectors_result = {
        extractor_kind: "job_board_selectors",
        selectors_tried: { "title" => [ "h1" ] },
        data: { title: "Engineer", description: "Desc" }
      }

      assert_difference -> { HtmlScrapingLog.where(scraping_attempt_id: attempt.id).count }, +1 do
        Scraping::Orchestration::Support::Observability.create_selectors_html_log(
          context,
          selectors_result,
          fetch_mode: "static",
          board_type: :greenhouse,
          html_size: 100,
          cleaned_html_size: 80
        )
      end
    end
  end
end
