# frozen_string_literal: true

module Scraping
  module JobBoards
    class JobviteExtractor < BaseExtractor
      protected

      def title_selectors
        [
          "h1",
          "[class*='jv-header'] h1",
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
          "[class*='jv-job-location']",
          "[class*='location']"
        ]
      end

      def description_selectors
        [
          "[class*='jv-job-detail-description']",
          "[class*='description']",
          "main"
        ]
      end
    end
  end
end
