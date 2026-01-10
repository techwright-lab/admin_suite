# frozen_string_literal: true

require "test_helper"

class ScrapedJobListingDataTest < ActiveSupport::TestCase
  test "normalize_url preserves resource-defining params like gh_jid and drops utm params" do
    url = "https://www.housecallpro.com/careers/open-positions/?gh_jid=5723833004&utm_source=twitter&utm_campaign=abc"
    normalized = ScrapedJobListingData.normalize_url(url)

    assert_includes normalized, "gh_jid=5723833004"
    assert_not_includes normalized, "utm_source"
    assert_not_includes normalized, "utm_campaign"
  end

  test "create_with_html is idempotent for same job_listing + normalized url + content_hash" do
    job_listing = create(:job_listing, url: "https://example.com/jobs/123?gh_jid=1")
    html = "<html><body><main>Hello</main></body></html>"

    first = ScrapedJobListingData.create_with_html(url: job_listing.url, html_content: html, job_listing: job_listing)
    second = ScrapedJobListingData.create_with_html(url: job_listing.url, html_content: html, job_listing: job_listing)

    assert_equal first.id, second.id
    assert_equal job_listing.id, second.job_listing_id
  end
end
