# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class CreateRound < BaseHandler
          def call(step)
            return { "action" => "create_round", "status" => "no_application" } unless app

            params = step["params"] || {}

            existing = app.interview_rounds.find_by(
              source_email_id: synced_email.id,
              stage: params["stage"],
              stage_name: params["stage_name"],
              scheduled_at: params["scheduled_at"]
            )
            if existing
              return { "action" => "create_round", "status" => "already_exists", "round_id" => existing.id }
            end

            position = app.interview_rounds.maximum(:position).to_i + 1

            round = app.interview_rounds.create!(
              stage: params["stage"],
              stage_name: params["stage_name"],
              scheduled_at: params["scheduled_at"],
              duration_minutes: params["duration_minutes"],
              interviewer_name: params["interviewer_name"],
              interviewer_role: params["interviewer_role"],
              video_link: params["video_link"],
              position: position,
              notes: params["notes"],
              source_email_id: synced_email.id
            )

            { "action" => "create_round", "round_id" => round.id }
          end
        end
      end
    end
  end
end
