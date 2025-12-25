# frozen_string_literal: true

module Assistant
  module Tools
    # Write: add a job role to the user's target job roles list.
    #
    # args:
    # - job_role_id (optional)
    # - job_role_title (optional, used to find-or-create)
    # - priority (optional)
    class AddTargetJobRoleTool < BaseTool
      def call(args:, tool_execution:)
        role = resolve_job_role(args)
        return { success: false, error: "Job role not found" } if role.nil?

        utjr = UserTargetJobRole.find_or_initialize_by(user: user, job_role: role)
        if (args["priority"] || args[:priority]).present?
          utjr.priority = (args["priority"] || args[:priority]).to_i
        end
        utjr.save!

        {
          success: true,
          data: {
            job_role: { id: role.id, title: role.title },
            target_job_role: { id: utjr.id, priority: utjr.priority }
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.record.errors.full_messages.join(", ") }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def resolve_job_role(args)
        job_role_id = (args["job_role_id"] || args[:job_role_id]).to_i
        return JobRole.find_by(id: job_role_id) if job_role_id.positive?

        title = (args["job_role_title"] || args[:job_role_title]).to_s.strip
        return nil if title.blank?

        JobRole.where("lower(title) = ?", title.downcase).first || JobRole.create!(title: title)
      end
    end
  end
end
