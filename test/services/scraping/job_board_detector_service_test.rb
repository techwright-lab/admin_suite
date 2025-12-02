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

    test "should detect linkedin" do
      url = "https://www.linkedin.com/jobs/view/123456"
      detector = JobBoardDetectorService.new(url)
      
      assert_equal :linkedin, detector.detect
      assert_not detector.api_supported?
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

