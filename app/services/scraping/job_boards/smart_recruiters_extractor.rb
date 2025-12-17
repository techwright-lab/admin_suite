# frozen_string_literal: true

module Scraping
  module JobBoards
    class SmartRecruitersExtractor < BaseExtractor
      protected

      def title_selectors
        [
          "h1",
          "[data-testid='job-title']",
          "[class*='job-title']"
        ]
      end

      def company_selectors
        [
          "meta[property='og:site_name']",
          "[class*='company']"
        ]
      end

      def location_selectors
        [
          "[data-testid='job-location']",
          "[class*='location']"
        ]
      end

      def description_selectors
        [
          "[data-testid='job-description']",
          "[class*='job-description']",
          "[class*='description']",
          "main"
        ]
      end
    end
  end
end
