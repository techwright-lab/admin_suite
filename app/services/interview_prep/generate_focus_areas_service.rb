# frozen_string_literal: true

module InterviewPrep
  class GenerateFocusAreasService < BaseGeneratorService
    private

    def kind
      :focus_areas
    end

    def prompt_class
      Ai::InterviewPrepFocusAreasPrompt
    end

    def normalize_parsed(parsed)
      items = Array(parsed.is_a?(Hash) ? parsed["focus_areas"] : nil)
      focus_areas = items.map do |item|
        next unless item.is_a?(Hash)

        {
          title: item["title"].to_s.strip,
          why_it_matters: item["why_it_matters"].to_s.strip,
          how_to_prepare: Array(item["how_to_prepare"]).map(&:to_s).map(&:strip).reject(&:blank?).first(8),
          experiences_to_use: Array(item["experiences_to_use"]).map(&:to_s).map(&:strip).reject(&:blank?).first(8)
        }.compact
      end.compact

      { focus_areas: focus_areas.first(6) }
    end
  end
end
