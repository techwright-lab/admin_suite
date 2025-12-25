# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: list the user's target companies.
    class ListTargetCompaniesTool < BaseTool
      def call(args:, tool_execution:)
        limit = (args["limit"] || args[:limit] || 50).to_i.clamp(1, 100)

        target_companies = user.user_target_companies
          .includes(:company)
          .ordered
          .limit(limit)

        {
          success: true,
          data: {
            count: target_companies.size,
            target_companies: target_companies.map { |utc|
              {
                id: utc.id,
                company_id: utc.company_id,
                company_name: utc.company&.name,
                priority: utc.priority,
                created_at: utc.created_at&.iso8601
              }
            }
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
