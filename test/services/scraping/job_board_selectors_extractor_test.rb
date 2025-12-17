# frozen_string_literal: true

require "test_helper"

module Scraping
  module JobBoards
    class JobBoardSelectorsExtractorTest < ActiveSupport::TestCase
      test "greenhouse extractor extracts title and description" do
        html = <<~HTML
          <html>
            <body>
              <h1 class="app-title">Staff Backend Engineer</h1>
              <div class="company-name">Acme Inc</div>
              <div id="content">
                <p>Build distributed systems.</p>
              </div>
            </body>
          </html>
        HTML

        extractor = ExtractorFactory.build(:greenhouse)
        result = extractor.extract(html)

        assert_equal true, result[:success]
        assert_equal "html", result[:extraction_method]
        assert_equal "greenhouse", result[:provider]
        assert_equal "Staff Backend Engineer", result.dig(:data, :title)
        assert_includes result.dig(:data, :description), "Build distributed systems"
        assert_operator result[:confidence].to_f, :>=, 0.7
      end

      test "unknown board falls back to base extractor" do
        extractor = ExtractorFactory.build(:unknown)
        assert_instance_of BaseExtractor, extractor
      end
    end
  end
end
