# frozen_string_literal: true

require "test_helper"

module Scraping
  module Orchestration
    module Steps
      class HandleLimitedSourcesTest < ActiveSupport::TestCase
        def setup
          @company = create(:company)
          @job_role = create(:job_role)
          @job_listing = create(:job_listing, company: @company, job_role: @job_role, url: "https://www.linkedin.com/jobs/view/123456")
          @attempt = create(:scraping_attempt, job_listing: @job_listing)
          @event_recorder = Scraping::EventRecorderService.new(@attempt)
          @step = HandleLimitedSources.new
        end

        def build_context(board_type: :linkedin, html_content: nil)
          context = OpenStruct.new(
            job_listing: @job_listing,
            attempt: @attempt,
            board_type: board_type,
            html_content: html_content || sample_linkedin_html,
            event_recorder: @event_recorder,
            limited_extraction: false
          )
          context
        end

        test "continues for non-limited boards" do
          context = build_context(board_type: :greenhouse)

          result = @step.call(context)

          assert_equal :continue, result
          assert_not context.limited_extraction
        end

        test "handles linkedin as limited source" do
          context = build_context(board_type: :linkedin)

          result = @step.call(context)

          assert_equal :continue, result
          assert context.limited_extraction
        end

        test "handles indeed as limited source" do
          context = build_context(board_type: :indeed)

          result = @step.call(context)

          assert_equal :continue, result
          assert context.limited_extraction
        end

        test "handles glassdoor as limited source" do
          context = build_context(board_type: :glassdoor)

          result = @step.call(context)

          assert_equal :continue, result
          assert context.limited_extraction
        end

        test "extracts title from og:title meta tag" do
          html = <<~HTML
            <html>
              <head>
                <meta property="og:title" content="Software Engineer at TechCorp | LinkedIn">
              </head>
              <body></body>
            </html>
          HTML

          context = build_context(html_content: html)
          @step.call(context)

          # Title should be parsed and cleaned
          @job_listing.reload
          assert_equal "limited", @job_listing.scraped_data["extraction_quality"]
        end

        test "extracts description from og:description meta tag" do
          html = <<~HTML
            <html>
              <head>
                <meta property="og:description" content="We are looking for a talented engineer...">
              </head>
              <body></body>
            </html>
          HTML

          context = build_context(html_content: html)
          @step.call(context)

          @job_listing.reload
          meta = @job_listing.scraped_data["meta_extraction"]
          assert_equal "We are looking for a talented engineer...", meta["description"]
        end

        test "extracts data from JSON-LD schema.org markup" do
          html = <<~HTML
            <html>
              <head>
                <script type="application/ld+json">
                  {
                    "@type": "JobPosting",
                    "title": "Senior Developer",
                    "description": "Build amazing products",
                    "hiringOrganization": {
                      "name": "Awesome Corp"
                    },
                    "jobLocation": {
                      "address": {
                        "addressLocality": "San Francisco"
                      }
                    }
                  }
                </script>
              </head>
              <body></body>
            </html>
          HTML

          context = build_context(html_content: html)
          @step.call(context)

          @job_listing.reload
          meta = @job_listing.scraped_data["meta_extraction"]
          assert_equal "Senior Developer", meta["title"]
          assert_equal "Awesome Corp", meta["company"]
          assert_equal "San Francisco", meta["location"]
        end

        test "records limited_source_handling event" do
          context = build_context

          assert_difference -> { ScrapingEvent.count }, 1 do
            @step.call(context)
          end

          event = ScrapingEvent.last
          assert_equal "limited_source_handling", event.event_type
          assert_equal "success", event.status
        end

        test "stores limited extraction reason in scraped_data" do
          context = build_context(board_type: :linkedin)
          @step.call(context)

          @job_listing.reload
          reason = @job_listing.scraped_data["limited_extraction_reason"]
          assert_includes reason, "LinkedIn"
          assert_includes reason, "authentication"
        end

        test "parses linkedin title correctly" do
          html = <<~HTML
            <html>
              <head>
                <meta property="og:title" content="Software Engineer at TechCorp | LinkedIn">
              </head>
              <body></body>
            </html>
          HTML

          context = build_context(html_content: html)
          @step.call(context)

          @job_listing.reload
          meta = @job_listing.scraped_data["meta_extraction"]
          # Should remove " | LinkedIn" and " at TechCorp" parts
          assert_equal "Software Engineer", meta["title"]
        end

        test "handles empty html content gracefully" do
          context = build_context(html_content: "")

          # Should not raise
          result = @step.call(context)

          assert_equal :continue, result
          assert context.limited_extraction
        end

        test "handles nil html content gracefully" do
          context = build_context(html_content: nil)
          context.html_content = nil

          # Should not raise
          result = @step.call(context)

          assert_equal :continue, result
        end

        private

        def sample_linkedin_html
          <<~HTML
            <html>
              <head>
                <title>Software Engineer - San Francisco | LinkedIn</title>
                <meta property="og:title" content="Software Engineer at Example Corp | LinkedIn">
                <meta property="og:description" content="We are looking for a talented engineer to join our team.">
                <meta property="og:site_name" content="LinkedIn">
              </head>
              <body>
                <div>Login required to view full content</div>
              </body>
            </html>
          HTML
        end
      end
    end
  end
end
