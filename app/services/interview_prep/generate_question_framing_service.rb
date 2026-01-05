# frozen_string_literal: true

module InterviewPrep
  class GenerateQuestionFramingService < BaseGeneratorService
    private

    def kind
      :question_framing
    end

    def prompt_class
      Ai::InterviewPrepQuestionFramingPrompt
    end

    def normalize_parsed(parsed)
      items = Array(parsed.is_a?(Hash) ? parsed["questions"] : nil)
      questions = items.map do |item|
        next unless item.is_a?(Hash)

        q = item["question"].to_s.strip
        next if q.blank?

        {
          question: q,
          framing: Array(item["framing"]).map(&:to_s).map(&:strip).reject(&:blank?).first(8),
          outline: Array(item["outline"]).map(&:to_s).map(&:strip).reject(&:blank?).first(8),
          pitfalls: Array(item["pitfalls"]).map(&:to_s).map(&:strip).reject(&:blank?).first(8)
        }
      end.compact

      { questions: questions.first(12) }
    end
  end
end
