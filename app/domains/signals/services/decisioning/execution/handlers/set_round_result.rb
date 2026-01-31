# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class SetRoundResult < BaseHandler
          def call(step)
            params = step["params"] || {}
            round = resolve_round(step["target"] || {})
            return { "action" => "set_round_result", "status" => "no_round_resolved" } unless round

            if round.result.to_s == params["result"].to_s && round.source_email_id == synced_email.id
              return {
                "action" => "set_round_result",
                "status" => "already_set",
                "round_id" => round.id,
                "result" => round.result
              }
            end

            round.update!(
              result: params["result"],
              completed_at: params["completed_at"] || Time.current,
              source_email_id: synced_email.id
            )

            { "action" => "set_round_result", "round_id" => round.id, "result" => round.result }
          end
        end
      end
    end
  end
end
