# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningExecutionJobListingFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "upsert_job_listing_from_url creates job listing and enqueue_scrape_job_listing enqueues job" do
    email = create(:synced_email, :processed)

    handler = Signals::Decisioning::Execution::Handlers::UpsertJobListingFromUrl.new(email)
    step = {
      "step_id" => "upsert",
      "action" => "upsert_job_listing_from_url",
      "target" => {},
      "params" => {
        "url" => "https://boards.greenhouse.io/acme/jobs/123?utm_source=x",
        "company_name" => "Acme",
        "job_role_title" => "Senior Engineer",
        "job_title" => "Senior Engineer",
        "source" => { "synced_email_id" => email.id }
      }
    }

    res = handler.call(step)
    assert res["job_listing_id"].present?
    jl = JobListing.find(res["job_listing_id"])
    assert_equal "https://boards.greenhouse.io/acme/jobs/123", jl.url

    enqueue_handler = Signals::Decisioning::Execution::Handlers::EnqueueScrapeJobListing.new(email)
    enqueue_step = {
      "step_id" => "enqueue",
      "action" => "enqueue_scrape_job_listing",
      "target" => {},
      "params" => {
        "url" => "https://boards.greenhouse.io/acme/jobs/123",
        "force" => false,
        "source" => { "synced_email_id" => email.id }
      }
    }

    clear_enqueued_jobs
    assert_enqueued_with(job: ScrapeJobListingJob) do
      enqueue_handler.call(enqueue_step)
    end
  end
end
