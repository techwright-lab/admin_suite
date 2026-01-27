# frozen_string_literal: true

module Signals
  module Rules
    class RejectionRule < BaseRule
      PRIORITY = 100

      def applies?(context)
        context.email_type == "rejection"
      end

      def actions(_context)
        [
          { type: :run_status_processor },
          { type: :mark_latest_round_failed }
        ]
      end
    end
  end
end
