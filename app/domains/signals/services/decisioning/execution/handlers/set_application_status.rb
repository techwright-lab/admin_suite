# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class SetApplicationStatus < BaseHandler
          def call(step)
            status = step.dig("params", "status")
            ctx = Signals::StateContext.new(synced_email)
            applier = Signals::ActionApplier.new(ctx)
            res = applier.apply!([ { type: :set_application_status, status: status&.to_sym } ])
            { "action" => "set_application_status", "status" => status, "result" => res }
          end
        end
      end
    end
  end
end
