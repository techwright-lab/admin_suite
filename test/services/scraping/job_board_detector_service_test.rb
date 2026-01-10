# frozen_string_literal: true

require "test_helper"

module Scraping
  class JobBoardDetectorServiceTest < ActiveSupport::TestCase
    test "should detect greenhouse" do
      url = "https://boards.greenhouse.io/company/jobs/123"
      detector = JobBoardDetectorService.new(url)

      assert_equal :greenhouse, detector.detect
      assert detector.api_supported?
      assert_equal "company", detector.company_slug
      assert_equal "123", detector.job_id
    end

    test "should detect lever" do
      url = "https://jobs.lever.co/company/job-id-123"
      detector = JobBoardDetectorService.new(url)

      assert_equal :lever, detector.detect
      assert detector.api_supported?
      assert_equal "company", detector.company_slug
      assert_equal "job-id-123", detector.job_id
    end

    test "should detect linkedin from direct job view URL" do
      url = "https://www.linkedin.com/jobs/view/4339207223"
      detector = JobBoardDetectorService.new(url)

      assert_equal :linkedin, detector.detect
      assert_not detector.api_supported?
      assert detector.limited_extraction?
      assert_equal "4339207223", detector.job_id
    end

    test "should detect linkedin from collections URL with currentJobId" do
      url = "https://www.linkedin.com/jobs/collections/recommended/?currentJobId=4339207223"
      detector = JobBoardDetectorService.new(url)

      assert_equal :linkedin, detector.detect
      assert_equal "4339207223", detector.job_id
      assert detector.limited_extraction?
    end

    test "should detect linkedin from search URL with currentJobId" do
      url = "https://www.linkedin.com/jobs/search/?currentJobId=9876543210&keywords=engineer"
      detector = JobBoardDetectorService.new(url)

      assert_equal :linkedin, detector.detect
      assert_equal "9876543210", detector.job_id
    end

    test "should return canonical URL for linkedin" do
      # Both URL formats should normalize to the same canonical URL
      urls = [
        "https://www.linkedin.com/jobs/view/4339207223/?alternateChannel=search&trackingId=xyz",
        "https://www.linkedin.com/jobs/collections/recommended/?currentJobId=4339207223&utm_source=google"
      ]

      urls.each do |url|
        detector = JobBoardDetectorService.new(url)
        assert_equal "https://www.linkedin.com/jobs/view/4339207223", detector.canonical_url
      end
    end

    test "limited_extraction? returns true for linkedin, indeed, glassdoor" do
      limited_urls = [
        "https://www.linkedin.com/jobs/view/123",
        "https://www.indeed.com/viewjob?jk=abc",
        "https://www.glassdoor.com/job-listing/123"
      ]

      limited_urls.each do |url|
        detector = JobBoardDetectorService.new(url)
        assert detector.limited_extraction?, "Expected #{url} to be limited extraction"
      end
    end

    test "limited_extraction? returns false for greenhouse, lever" do
      full_urls = [
        "https://boards.greenhouse.io/company/jobs/123",
        "https://jobs.lever.co/company/abc-123"
      ]

      full_urls.each do |url|
        detector = JobBoardDetectorService.new(url)
        assert_not detector.limited_extraction?, "Expected #{url} to NOT be limited extraction"
      end
    end

    test "should detect indeed" do
      url = "https://www.indeed.com/viewjob?jk=123456"
      detector = JobBoardDetectorService.new(url)

      assert_equal :indeed, detector.detect
    end

    test "should detect workable" do
      url = "https://apply.workable.com/company/j/123/"
      detector = JobBoardDetectorService.new(url)

      assert_equal :workable, detector.detect
      assert_equal "company", detector.company_slug
    end

    test "should return unknown for unsupported domain" do
      url = "https://random-company.com/careers/123"
      detector = JobBoardDetectorService.new(url)

      assert_equal :unknown, detector.detect
      assert_not detector.api_supported?
    end

    test "should extract job id from various patterns" do
      patterns = {
        "https://example.com/jobs/123" => "123",
        "https://example.com/position/abc-def" => "abc-def",
        "https://example.com/careers?job_id=xyz" => "xyz"
      }

      patterns.each do |url, expected_id|
        detector = JobBoardDetectorService.new(url)
        assert_equal expected_id, detector.job_id
      end
    end
  end
end
