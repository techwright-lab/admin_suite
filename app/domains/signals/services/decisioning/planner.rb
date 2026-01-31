# frozen_string_literal: true

module Signals
  module Decisioning
    # Deterministic baseline planner that drives decisions from EmailFacts.
    #
    # This planner should not rely on legacy regex classification directly; it
    # should rely on `DecisionInput.facts` and the evidence strings within it.
    class Planner
      VERSION = "2026-01-27".freeze

      RULES = [
        Signals::Decisioning::Rules::OpportunityRule,
        Signals::Decisioning::Rules::SchedulingRule,
        Signals::Decisioning::Rules::RoundFeedbackRule,
        Signals::Decisioning::Rules::StatusUpdateRule
      ].freeze

      def initialize(decision_input)
        @input = decision_input
      end

      def plan
        RULES.each do |rule_class|
          res = rule_class.new(input).call
          next if res.nil?

          if res[:decision] == "noop"
            return noop(res[:reason])
          end

          return apply(confidence: res[:confidence], reasons: res[:reasons], steps: res[:steps])
        end

        return noop("unmatched_email") unless input.dig("match", "matched")

        noop("unsupported_kind")
      end

      private

      attr_reader :input

      def noop(reason)
        {
          "version" => VERSION,
          "decision" => "noop",
          "confidence" => 1.0,
          "reasons" => [ reason ],
          "plan" => []
        }
      end

      def apply(confidence:, reasons:, steps:)
        {
          "version" => VERSION,
          "decision" => "apply",
          "confidence" => confidence,
          "reasons" => reasons,
          "plan" => steps
        }
      end
    end
  end
end
