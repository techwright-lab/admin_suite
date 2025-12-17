# frozen_string_literal: true

module Scraping
  module JobBoards
    class GreenhouseExtractor < BaseExtractor
      protected

      def title_selectors
        [
          "h1.app-title",
          "h1",
          "[data-testid='job-title']"
        ]
      end

      def company_selectors
        [
          ".company-name",
          "[class*='company'] a",
          "meta[property='og:site_name']"
        ]
      end

      def location_selectors
        [
          "#location",
          ".location",
          "[class*='location']"
        ]
      end

      def description_selectors
        [
          "#content",
          "#job_description",
          ".content",
          "[id*='description']",
          "[class*='description']"
        ]
      end

      def about_company_selectors
        [
          "#content",
          "[id*='about']",
          "[class*='about']",
          ".about",
          ".about-us"
        ]
      end

      def company_culture_selectors
        [
          "[id*='culture']",
          "[class*='culture']",
          "[id*='values']",
          "[class*='values']",
          "[id*='mission']",
          "[class*='mission']"
        ]
      end
    end
  end
end
