# frozen_string_literal: true

module Scraping
  module JobBoards
    class BambooHrExtractor < BaseExtractor
      protected

      def title_selectors
        [
          "h1",
          "[class*='BambooHR'] h1",
          "[data-automation-id='jobPostingHeader']"
        ]
      end

      def location_selectors
        [
          "[class*='location']",
          "[data-automation-id='jobPostingLocation']"
        ]
      end

      def description_selectors
        [
          "[class*='jobDescription']",
          "[class*='description']",
          "main"
        ]
      end
    end
  end
end
