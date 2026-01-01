# frozen_string_literal: true

module Assistant
  module Tools
    # Write: remove one or more job roles from the user's target job roles list.
    #
    # args:
    # - job_role_id (optional)
    # - job_role_title (optional, used to find)
    # - job_roles (optional, array of {job_role_id?, job_role_title?})
    class RemoveTargetJobRoleTool < BaseTool
      def call(args:, tool_execution:)
        if args["job_roles"].is_a?(Array) || args[:job_roles].is_a?(Array)
          return remove_many(args)
        end

        remove_one(args)
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def remove_one(args)
        role = find_job_role(args)
        return { success: false, error: "Job role not found" } if role.nil?

        utjr = UserTargetJobRole.find_by(user: user, job_role: role)
        if utjr
          utjr.destroy!
          { success: true, data: { removed: true, job_role: { id: role.id, title: role.title } } }
        else
          { success: true, data: { removed: false, job_role: { id: role.id, title: role.title } } }
        end
      end

      def remove_many(args)
        items = args["job_roles"]
        items = args[:job_roles] if items.nil?
        items = Array(items)

        results = items.map do |item|
          item = item.is_a?(Hash) ? item : {}
          r = remove_one(item)
          {
            input: item,
            success: r[:success] == true,
            data: r[:data],
            error: r[:error]
          }.compact
        rescue StandardError => e
          { input: item, success: false, error: e.message }
        end

        failures = results.count { |r| r[:success] == false }

        {
          success: failures.zero?,
          data: {
            removed_count: results.count { |r| r.dig(:data, :removed) == true },
            not_found_or_noop_count: results.count { |r| r[:success] == true && r.dig(:data, :removed) == false },
            failed_count: failures,
            results: results
          }
        }
      end

      def find_job_role(args)
        job_role_id = (args["job_role_id"] || args[:job_role_id]).to_i
        return JobRole.find_by(id: job_role_id) if job_role_id.positive?

        title = (args["job_role_title"] || args[:job_role_title]).to_s.strip
        return nil if title.blank?

        JobRole.where("lower(title) = ?", title.downcase).first
      end
    end
  end
end
