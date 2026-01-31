# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class UpdateRound < BaseHandler
          def call(step)
            params = step["params"] || {}
            round = resolve_round(step["target"] || {})
            return { "action" => "update_round", "status" => "no_round_resolved" } unless round

            notes = round.notes.to_s
            notes_append = params["notes_append"].to_s
            if notes_append.present? && !notes.include?(notes_append)
              notes = [ notes, notes_append ].reject(&:blank?).join("\n").presence.to_s
            end

            round.update!(
              scheduled_at: params["scheduled_at"] || round.scheduled_at,
              duration_minutes: params["duration_minutes"] || round.duration_minutes,
              interviewer_name: params["interviewer_name"] || round.interviewer_name,
              interviewer_role: params["interviewer_role"] || round.interviewer_role,
              video_link: params["video_link"] || round.video_link,
              notes: notes.presence,
              source_email_id: synced_email.id
            )

            { "action" => "update_round", "round_id" => round.id }
          end
        end
      end
    end
  end
end
