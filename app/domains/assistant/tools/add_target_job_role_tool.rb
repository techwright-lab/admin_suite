# frozen_string_literal: true

module Assistant
  module Tools
    # Write: add a job role to the user's target job roles list.
    #
    # args:
    # - job_role_id (optional)
    # - job_role_title (optional, used to find-or-create)
    # - priority (optional)
    # - job_roles (optional, array of {job_role_id?, job_role_title?, priority?})
    class AddTargetJobRoleTool < BaseTool
      def call(args:, tool_execution:)
        if args["job_roles"].is_a?(Array) || args[:job_roles].is_a?(Array)
          return add_many(args)
        end

        add_one(args)
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.record.errors.full_messages.join(", ") }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def add_one(args)
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
      end

      def add_many(args)
        items = args["job_roles"]
        items = args[:job_roles] if items.nil?
        items = Array(items)

        results = items.map do |item|
          item = item.is_a?(Hash) ? item : {}
          r = add_one(item)
          {
            input: item,
            success: r[:success] == true,
            data: r[:data],
            error: r[:error]
          }.compact
        rescue StandardError => e
          { input: item, success: false, error: e.message }
        end

        successes = results.count { |r| r[:success] == true }
        failures = results.count { |r| r[:success] == false }

        {
          success: failures.zero?,
          data: {
            added_count: successes,
            failed_count: failures,
            results: results
          }
        }
      end

      def resolve_job_role(args)
        job_role_id = (args["job_role_id"] || args[:job_role_id]).to_i
        if job_role_id.positive?
          found = JobRole.find_by(id: job_role_id)
          return found if found
          # If the model provided an ID that doesn't exist in our DB, fall back to title-based lookup/creation.
        end

        title = (args["job_role_title"] || args[:job_role_title]).to_s.strip
        return nil if title.blank?

        JobRole.where("lower(title) = ?", title.downcase).first || JobRole.create!(title: title)
      end
    end
  end
end
