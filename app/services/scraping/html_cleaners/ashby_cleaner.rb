# frozen_string_literal: true

module Scraping
  module HtmlCleaners
    # HTML cleaner optimized for Ashby job board pages (jobs.ashbyhq.com)
    #
    # Ashby uses React with dynamically generated class names like `_title_ud4nd_34`.
    # Key structural elements have stable classes like `ashby-job-posting-*`.
    class AshbyCleaner < BaseCleaner
      def initialize
        super(board_type: :ashbyhq)
      end

      protected

      # Ashby-specific elements to remove
      def elements_to_remove
        super + [
          # Ashby navigation and back button
          ".ashby-job-board-back-to-all-jobs-button",
          "[class*='_navRoot_']",
          "[class*='_navContainer_']",
          # Tab navigation (Overview/Application tabs)
          "[role='tablist']",
          "[class*='_tabs_']",
          # Application form (we just want the job description)
          "[class*='_applicationForm_']",
          "form",
          # Social sharing
          "[class*='share']", "[class*='social']"
        ]
      end

      # Ashby-specific content selectors in priority order
      def main_content_selectors
        [
          # Primary content area (job description)
          ".ashby-job-posting-right-pane",
          # Container with all job details
          "[class*='_details_']",
          "[class*='_content_']",
          # Left pane has metadata (location, type, etc.)
          ".ashby-job-posting-left-pane",
          # React root as fallback
          "#root",
          # Generic fallbacks
          "body"
        ]
      end

      # Preserve job-related content even if it matches removal patterns
      def elements_to_preserve
        [
          ".ashby-job-posting-heading",
          ".ashby-job-posting-right-pane",
          ".ashby-job-posting-left-pane",
          "[class*='_section_']"
        ]
      end
    end
  end
end
