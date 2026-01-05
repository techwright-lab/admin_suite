# frozen_string_literal: true

module InterviewPrep
  class GenerateStrengthPositioningService < BaseGeneratorService
    private

    def kind
      :strength_positioning
    end

    def prompt_class
      Ai::InterviewPrepStrengthPositioningPrompt
    end

    def normalize_parsed(parsed)
      items = Array(parsed.is_a?(Hash) ? parsed["strengths"] : nil)
      strengths = items.map do |item|
        next unless item.is_a?(Hash)

        title = item["title"].to_s.strip
        next if title.blank?

        {
          title: title,
          positioning: item["positioning"].to_s.strip,
          evidence_types: Array(item["evidence_types"]).map(&:to_s).map(&:strip).reject(&:blank?).first(8)
        }
      end.compact

      { strengths: strengths.first(10) }
    end
  end
end
