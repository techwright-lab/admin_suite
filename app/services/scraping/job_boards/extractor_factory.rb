# frozen_string_literal: true

module Scraping
  module JobBoards
    # Factory for mapping detected board types to selectors-first extractors.
    class ExtractorFactory
      def self.build(board_type)
        case board_type&.to_sym
        when :greenhouse
          GreenhouseExtractor.new(board_type: :greenhouse)
        when :lever
          LeverExtractor.new(board_type: :lever)
        when :workable
          WorkableExtractor.new(board_type: :workable)
        when :ashbyhq
          AshbyExtractor.new(board_type: :ashbyhq)
        when :smartrecruiters
          SmartRecruitersExtractor.new(board_type: :smartrecruiters)
        when :bamboohr
          BambooHrExtractor.new(board_type: :bamboohr)
        when :icims
          IcimsExtractor.new(board_type: :icims)
        when :jobvite
          JobviteExtractor.new(board_type: :jobvite)
        else
          BaseExtractor.new(board_type: (board_type || :unknown))
        end
      end
    end
  end
end
