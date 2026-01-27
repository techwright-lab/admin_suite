# frozen_string_literal: true

module Signals
  module Rules
    class OfferRule < BaseRule
      PRIORITY = 80

      def applies?(context)
        context.email_type == "offer"
      end

      def actions(_context)
        [
          { type: :run_status_processor }
        ]
      end
    end
  end
end
