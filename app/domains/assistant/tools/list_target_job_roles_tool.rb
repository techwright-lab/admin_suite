# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: list the user's target job roles.
    class ListTargetJobRolesTool < BaseTool
      def call(args:, tool_execution:)
        limit = (args["limit"] || args[:limit] || 50).to_i.clamp(1, 100)

        target_roles = user.user_target_job_roles
          .includes(:job_role)
          .ordered
          .limit(limit)

        {
          success: true,
          data: {
            count: target_roles.size,
            target_job_roles: target_roles.map { |utjr|
              {
                id: utjr.id,
                job_role_id: utjr.job_role_id,
                job_role_title: utjr.job_role&.title,
                priority: utjr.priority,
                created_at: utjr.created_at&.iso8601
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

