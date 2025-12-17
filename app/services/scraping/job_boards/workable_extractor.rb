# frozen_string_literal: true

module Scraping
  module JobBoards
    class WorkableExtractor < BaseExtractor
      protected

      def title_selectors
        [
          "h1[data-ui='job-title']",
          "h1",
          "[class*='job-title']"
        ]
      end

      def company_selectors
        [
          "[data-ui='company-name']",
          "[class*='company']",
          "meta[property='og:site_name']"
        ]
      end

      def location_selectors
        [
          "[data-ui='job-location']",
          "[class*='location']"
        ]
      end

      def description_selectors
        [
          "[data-ui='job-description']",
          "[class*='job-description']",
          "[class*='description']"
        ]
      end
    end
  end
end
