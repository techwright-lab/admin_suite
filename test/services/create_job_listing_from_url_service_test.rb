# frozen_string_literal: true

require "test_helper"

class CreateJobListingFromUrlServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creates job listing, associates to application, and enqueues scraping" do
    application = create(:interview_application)
    url = "https://boards.greenhouse.io/acme/jobs/123?utm_source=x"

    clear_enqueued_jobs
    service = CreateJobListingFromUrlService.new(application, url)
    job_listing = nil

    assert_enqueued_with(job: ScrapeJobListingJob) do
      job_listing = service.call
    end

    assert job_listing.present?
    assert_equal "https://boards.greenhouse.io/acme/jobs/123", job_listing.url
    assert_equal job_listing.id, application.reload.job_listing_id
  end
end
