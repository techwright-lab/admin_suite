# frozen_string_literal: true

require "test_helper"

class QuickApplyFromUrlServiceTest < ActiveSupport::TestCase
  test "quick apply is idempotent: re-running does not create duplicate job listing or application" do
    user = create(:user)
    url = "https://www.housecallpro.com/careers/open-positions/?gh_jid=5697393004&gh_src=abc123"
    normalized_url = ScrapedJobListingData.normalize_url(url)

    # Make extraction deterministic and fast in test (no real network).
    fake_orchestrator = Class.new do
      def call = true
    end.new

    original_new = Scraping::OrchestratorService.method(:new)
    Scraping::OrchestratorService.define_singleton_method(:new) { |_job_listing| fake_orchestrator }

    assert_difference -> { JobListing.where(url: normalized_url).count }, +1 do
      assert_difference -> { user.interview_applications.count }, +1 do
        QuickApplyFromUrlService.new(url, user).call
      end
    end

    # Run again; should not create duplicates
    assert_no_difference -> { JobListing.where(url: normalized_url).count } do
      assert_no_difference -> { user.interview_applications.count } do
        QuickApplyFromUrlService.new(url, user).call
      end
    end
  ensure
    Scraping::OrchestratorService.define_singleton_method(:new, original_new)
  end
end
