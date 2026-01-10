# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class Scraping::Orchestration::Steps::ResolveEmbeddedJobBoardTest < ActiveSupport::TestCase
  test "resolves Greenhouse gh_jid pages by fetching job-boards embed HTML and swapping context html" do
    job_listing = create(
      :job_listing,
      url: "https://www.housecallpro.com/careers/open-positions/?gh_jid=5723833004&gh_src=8d8dbb194us"
    )
    attempt = create(:scraping_attempt, job_listing: job_listing, url: job_listing.url, domain: "www.housecallpro.com")
    recorder = Scraping::EventRecorderService.new(attempt, job_listing: job_listing)
    context = Scraping::Orchestration::Context.new(job_listing: job_listing, attempt: attempt, event_recorder: recorder)
    context.board_type = :greenhouse

    context.html_content = <<~HTML
      <html>
        <head>
          <link rel="preload" as="script" href="https://boards.greenhouse.io/embed/job_board/js?for=housecall" />
        </head>
        <body>
          <div id="greenhouse-loading">Loading…</div>
        </body>
      </html>
    HTML

    embed_url = "https://job-boards.greenhouse.io/embed/job_board?for=housecall&gh_jid=5723833004&gh_src=8d8dbb194us"
    embed_html = "<html><body><main>#{'A' * 1200}</main><h1>Senior Software Engineer</h1></body></html>"

    stub_request(:get, embed_url)
      .with { |req| req.headers["Accept"] == "text/html" }
      .to_return(status: 200, body: embed_html, headers: { "Content-Type" => "text/html" })

    outcome = Scraping::Orchestration::Steps::ResolveEmbeddedJobBoard.new.call(context)

    assert_equal :continue, outcome
    assert_equal "greenhouse_embed", context.fetch_mode
    assert_includes context.html_content, "Senior Software Engineer"
    assert context.cleaned_html.present?

    event = attempt.scraping_events.order(:created_at).last
    assert_equal "embedded_job_board_fetch", event.event_type
    assert_equal "success", event.status
    assert_equal 200, event.output_payload["http_status"]
    assert_equal "greenhouse_embed", event.output_payload["fetch_mode"]
    assert event.output_payload["cleaned_text_length"].to_i >= 800
  end

  test "no-ops when no gh_jid is present" do
    job_listing = create(:job_listing, url: "https://www.housecallpro.com/careers/open-positions/")
    attempt = create(:scraping_attempt, job_listing: job_listing, url: job_listing.url, domain: "www.housecallpro.com")
    recorder = Scraping::EventRecorderService.new(attempt, job_listing: job_listing)
    context = Scraping::Orchestration::Context.new(job_listing: job_listing, attempt: attempt, event_recorder: recorder)
    context.board_type = :greenhouse
    context.html_content = "<html><head></head><body></body></html>"

    assert_equal :continue, Scraping::Orchestration::Steps::ResolveEmbeddedJobBoard.new.call(context)
    assert_equal 0, attempt.scraping_events.count
  end
end
