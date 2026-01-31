# frozen_string_literal: true

require "test_helper"

class HtmlScrapingServiceSalaryTest < ActiveSupport::TestCase
  test "does not extract salary from unrelated numeric ranges without money signals" do
    html = <<~HTML
      <html>
        <body>
          <h1>Principal Software Engineer</h1>
          <div class="description">
            After 20 years of creating software...
            This text contains an unrelated range 89 - 7 and should not be treated as compensation.
          </div>
        </body>
      </html>
    HTML

    svc = Scraping::HtmlScrapingService.new
    res = svc.extract(html, "https://example.com/job/1")

    assert_nil res[:salary_min]
    assert_nil res[:salary_max]
    assert_nil res[:salary_currency]
  end

  test "extracts salary when currency and annual range are present" do
    html = <<~HTML
      <html>
        <body>
          <h1>Senior Engineer</h1>
          <div class="compensation">Compensation: $120,000 - $150,000 USD per year</div>
        </body>
      </html>
    HTML

    svc = Scraping::HtmlScrapingService.new
    res = svc.extract(html, "https://example.com/job/2")

    assert_equal 120_000.0, res[:salary_min]
    assert_equal 150_000.0, res[:salary_max]
    assert_equal "USD", res[:salary_currency]
  end
end
