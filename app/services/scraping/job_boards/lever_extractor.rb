# frozen_string_literal: true

module Scraping
  module JobBoards
    class LeverExtractor < BaseExtractor
      protected

      def title_selectors
        [
          "h2.posting-headline",
          "h1",
          "[data-qa='posting-name']"
        ]
      end

      def company_selectors
        [
          ".main-header-logo img[alt]",
          "meta[property='og:site_name']"
        ]
      end

      def location_selectors
        [
          ".posting-categories .location",
          "[class*='location']"
        ]
      end

      def description_selectors
        [
          ".posting-description",
          "[class*='posting-description']",
          "[class*='description']"
        ]
      end
    end
  end
end
