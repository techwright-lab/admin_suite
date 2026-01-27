# frozen_string_literal: true

module Signals
  module Rules
    class RoundFeedbackRule < BaseRule
      PRIORITY = 70

      def applies?(context)
        context.email_type == "round_feedback"
      end

      def actions(_context)
        [
          { type: :run_round_feedback_processor },
          { type: :sync_application_from_round_result }
        ]
      end
    end
  end
end
