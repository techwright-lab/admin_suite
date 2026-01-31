# frozen_string_literal: true

require "test_helper"

class OpportunitiesCreateApplicationServiceJobListingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creates (and reuses) job listing via shared upsert service" do
    user = create(:user)
    opportunity = create(
      :opportunity,
      user: user,
      status: "new",
      job_url: "https://boards.greenhouse.io/acme/jobs/123?utm_source=newsletter",
      company_name: "Acme",
      job_role_title: "Senior Engineer"
    )

    clear_enqueued_jobs
    res = Opportunities::CreateApplicationService.new(opportunity, user).call
    assert_equal true, res[:success], res[:error]
    assert res[:job_listing].present?

    jl = res[:job_listing]
    assert_equal "https://boards.greenhouse.io/acme/jobs/123", jl.url
    assert_equal "123", jl.source_id
    assert_equal jl.id, opportunity.reload.job_listing_id

    # Re-run should reuse the same job listing (no duplication).
    opportunity2 = create(
      :opportunity,
      user: user,
      status: "new",
      job_url: "https://boards.greenhouse.io/acme/jobs/123?utm_campaign=x",
      company_name: "Acme",
      job_role_title: "Senior Engineer"
    )
    res2 = Opportunities::CreateApplicationService.new(opportunity2, user).call
    assert_equal jl.id, res2[:job_listing].id
  end
end
