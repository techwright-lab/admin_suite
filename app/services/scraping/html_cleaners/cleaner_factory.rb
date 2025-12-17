# frozen_string_literal: true

module Scraping
  module HtmlCleaners
    # Factory for creating board-specific HTML cleaners
    #
    # Returns specialized cleaners for known job boards, or a generic cleaner otherwise.
    class CleanerFactory
      CLEANER_MAP = {
        ashbyhq: AshbyCleaner,
        ashby: AshbyCleaner
        # Add more as needed:
        # greenhouse: GreenhouseCleaner,
        # lever: LeverCleaner,
        # workable: WorkableCleaner,
      }.freeze

      class << self
        # Returns appropriate cleaner for the given board type
        #
        # @param board_type [Symbol, String, nil] The job board type
        # @return [BaseCleaner] A cleaner instance
        def cleaner_for(board_type)
          return BaseCleaner.new if board_type.blank?

          key = board_type.to_s.downcase.to_sym
          cleaner_class = CLEANER_MAP[key] || BaseCleaner
          cleaner_class.new
        end

        # Returns a cleaner based on URL detection
        #
        # @param url [String] The job listing URL
        # @return [BaseCleaner] A cleaner instance
        def cleaner_for_url(url)
          return BaseCleaner.new if url.blank?

          detector = Scraping::JobBoardDetectorService.new(url)
          cleaner_for(detector.detect)
        end
      end
    end
  end
end
