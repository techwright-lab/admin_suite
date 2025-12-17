# frozen_string_literal: true

module Scraping
  module JobBoards
    class IcimsExtractor < BaseExtractor
      protected

      def title_selectors
        [
          "h1",
          "#header h1",
          "[class*='iCIMS'] h1"
        ]
      end

      def location_selectors
        [
          "[class*='location']",
          "[id*='location']"
        ]
      end

      def description_selectors
        [
          "#job-content",
          "[id*='jobDescription']",
          "[class*='description']",
          "main"
        ]
      end
    end
  end
end
