# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class CreateCompanyFeedback < BaseHandler
          def call(step)
            return { "action" => "create_company_feedback", "status" => "no_application" } unless app

            params = step["params"] || {}
            existing = CompanyFeedback.find_by(interview_application_id: app.id)
            if existing
              # Idempotency: avoid duplicate feedback due to association caching during replays.
              if existing.source_email_id == synced_email.id
                return {
                  "action" => "create_company_feedback",
                  "status" => "already_exists",
                  "feedback_id" => existing.id
                }
              end

              return {
                "action" => "create_company_feedback",
                "status" => "already_exists",
                "feedback_id" => existing.id
              }
            end

            fb = CompanyFeedback.create!(
              interview_application: app,
              source_email_id: synced_email.id,
              feedback_type: params["feedback_type"],
              feedback_text: params["feedback_text"],
              rejection_reason: params["rejection_reason"],
              next_steps: params["next_steps"],
              received_at: synced_email.email_date || Time.current
            )

            { "action" => "create_company_feedback", "feedback_id" => fb.id }
          end
        end
      end
    end
  end
end
