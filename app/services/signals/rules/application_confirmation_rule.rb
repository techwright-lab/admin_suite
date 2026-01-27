# frozen_string_literal: true

module Signals
  module Rules
    class ApplicationConfirmationRule < BaseRule
      PRIORITY = 20

      def applies?(context)
        context.email_type == "application_confirmation"
      end

      def actions(_context)
        [
          { type: :set_pipeline_stage, stage: :applied }
        ]
      end
    end
  end
end
