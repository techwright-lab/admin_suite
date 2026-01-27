# frozen_string_literal: true

module Signals
  module Rules
    class SchedulingRule < BaseRule
      PRIORITY = 40

      PROCESSABLE_TYPES = %w[scheduling interview_invite interview_reminder].freeze

      def applies?(context)
        PROCESSABLE_TYPES.include?(context.email_type)
      end

      def actions(_context)
        [
          { type: :run_interview_round_processor },
          { type: :sync_pipeline_from_round_stage }
        ]
      end
    end
  end
end
