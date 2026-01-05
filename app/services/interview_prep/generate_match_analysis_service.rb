# frozen_string_literal: true

module InterviewPrep
  class GenerateMatchAnalysisService < BaseGeneratorService
    private

    def kind
      :match_analysis
    end

    def prompt_class
      Ai::InterviewPrepMatchPrompt
    end

    def normalize_parsed(parsed)
      return {} unless parsed.is_a?(Hash)

      {
        match_label: parsed["match_label"].to_s,
        strong_in: Array(parsed["strong_in"]).map(&:to_s).map(&:strip).reject(&:blank?).first(10),
        partial_in: Array(parsed["partial_in"]).map(&:to_s).map(&:strip).reject(&:blank?).first(10),
        missing_or_risky: Array(parsed["missing_or_risky"]).map(&:to_s).map(&:strip).reject(&:blank?).first(10),
        notes: parsed["notes"].to_s.truncate(600)
      }
    end
  end
end
