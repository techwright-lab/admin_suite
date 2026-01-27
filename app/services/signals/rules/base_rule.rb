# frozen_string_literal: true

module Signals
  module Rules
    # Base rule for signal processing.
    class BaseRule < ApplicationService
      DEFAULT_PRIORITY = 0

      def priority
        self.class::PRIORITY
      rescue NameError
        DEFAULT_PRIORITY
      end

      def safe_applies?(context)
        applies?(context)
      rescue StandardError => e
        notify_error(
          e,
          context: "signal_rule_applies",
          user: context.synced_email&.user,
          synced_email_id: context.synced_email&.id,
          application_id: context.application&.id,
          rule: self.class.name
        )
        log_error("Rule #{self.class.name} applies? failed: #{e.message}")
        false
      end

      def safe_actions(context)
        actions(context)
      rescue StandardError => e
        notify_error(
          e,
          context: "signal_rule_actions",
          user: context.synced_email&.user,
          synced_email_id: context.synced_email&.id,
          application_id: context.application&.id,
          rule: self.class.name
        )
        log_error("Rule #{self.class.name} actions failed: #{e.message}")
        []
      end

      def applies?(_context)
        false
      end

      def actions(_context)
        []
      end
    end
  end
end
