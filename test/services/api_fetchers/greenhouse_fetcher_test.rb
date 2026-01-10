# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class ApiFetchers::GreenhouseFetcherTest < ActiveSupport::TestCase
  test "fetch returns decoded HTML content and company name from boards api" do
    Setting.set(name: "greenhouse_enabled", value: true)

    url = "https://www.housecallpro.com/careers/open-positions/?gh_jid=5751948004&gh_src=abc"

    stub_request(:get, "https://boards-api.greenhouse.io/v1/boards/housecall/jobs/5751948004")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          "title" => "Software Engineer",
          "company_name" => "Housecall Pro",
          "location" => { "name" => "Brazil" },
          "content" => "&lt;p&gt;Hello&lt;/p&gt;"
        }.to_json
      )

    result = ApiFetchers::GreenhouseFetcher.new.fetch(url: url, company_slug: "housecall", job_id: "5751948004")

    assert_equal 1.0, result[:confidence]
    assert_equal "Housecall Pro", result[:company]
    assert_includes result[:description], "<p>"
    assert_not_includes result[:description], "&lt;p&gt;"
  end
end
