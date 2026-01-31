# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class SetPipelineStage < BaseHandler
          def call(step)
            stage = step.dig("params", "stage")
            ctx = Signals::StateContext.new(synced_email)
            applier = Signals::ActionApplier.new(ctx)
            res = applier.apply!([ { type: :set_pipeline_stage, stage: stage&.to_sym } ])
            { "action" => "set_pipeline_stage", "stage" => stage, "result" => res }
          end
        end
      end
    end
  end
end
