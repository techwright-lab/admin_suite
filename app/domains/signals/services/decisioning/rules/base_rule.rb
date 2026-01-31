# frozen_string_literal: true

module Signals
  module Decisioning
    module Rules
      class BaseRule
        def initialize(input)
          @input = input
        end

        private

        attr_reader :input

        def kind
          input.dig("facts", "classification", "kind").to_s
        end

        def matched?
          !!input.dig("match", "matched")
        end

        def app_id
          input.dig("application", "id")
        end

        def email_id
          input.dig("event", "synced_email_id")
        end

        def email_date
          input.dig("event", "email_date")
        end

        def step_factory
          @step_factory ||= Signals::Decisioning::StepFactory.new(
            application_id: app_id,
            synced_email_id: email_id,
            email_date: email_date
          )
        end
      end
    end
  end
end
