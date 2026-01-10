# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: list the user's target domains.
    class ListTargetDomainsTool < BaseTool
      def call(args:, tool_execution:)
        limit = (args["limit"] || args[:limit] || 50).to_i.clamp(1, 100)

        target_domains = user.user_target_domains
          .includes(:domain)
          .ordered
          .limit(limit)

        {
          success: true,
          data: {
            count: target_domains.size,
            target_domains: target_domains.map { |utd|
              {
                id: utd.id,
                domain_id: utd.domain_id,
                domain_name: utd.domain&.name,
                priority: utd.priority,
                created_at: utd.created_at&.iso8601
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
