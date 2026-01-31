# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class CreateOpportunity < BaseHandler
          def call(step)
            params = step["params"] || {}
            synced_email_id = params.dig("source", "synced_email_id") || synced_email.id

            existing = Opportunity.find_by(synced_email_id: synced_email_id)
            if existing
              return { "action" => "create_opportunity", "status" => "already_exists", "opportunity_id" => existing.id }
            end

            opp = Opportunity.create!(
              user: synced_email.user,
              synced_email_id: synced_email_id,
              status: "new",
              company_name: params["company_name"],
              job_role_title: params["job_title"],
              job_url: params["job_url"],
              recruiter_name: params["recruiter_name"],
              recruiter_email: params["recruiter_email"],
              extracted_links: params["extracted_links"] || [],
              email_snippet: synced_email.snippet || synced_email.body_preview&.truncate(500)
            )

            { "action" => "create_opportunity", "opportunity_id" => opp.id }
          end
        end
      end
    end
  end
end
