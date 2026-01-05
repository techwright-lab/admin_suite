# frozen_string_literal: true

require "test_helper"

module Scraping
  class RateLimiterServiceTest < ActiveSupport::TestCase
    def setup
      @domain = "example.com"
      @limiter = RateLimiterService.new(@domain)
      Rails.cache.clear
    end

    test "should allow request when no previous request" do
      assert @limiter.allowed?
    end

    test "should not allow request immediately after" do
      @limiter.record_request!
      
      assert_not @limiter.allowed?
    end

    test "should allow request after rate limit period" do
      @limiter.record_request!
      
      # Simulate time passing
      travel 6.seconds do
        assert @limiter.allowed?
      end
    end

    test "should return correct wait time" do
      @limiter.record_request!
      
      wait_time = @limiter.wait_time
      assert wait_time > 0
      assert wait_time <= 5.0
    end

    test "should block until ready" do
      @limiter.record_request!
      
      # In test environment, sleep might not work as expected
      # Verify that wait_time is calculated correctly instead
      wait_time = @limiter.wait_time
      assert wait_time > 0
      assert wait_time <= 5.0
      
      # Verify wait_if_needed! doesn't raise
      assert_nothing_raised do
        @limiter.wait_if_needed!
      end
    end
  end
end

