# frozen_string_literal: true

module Assistant
  module Tools
    # Write: add a company to the user's target companies list.
    #
    # args:
    # - company_id (optional)
    # - company_name (optional, used to find-or-create)
    # - priority (optional)
    # - companies (optional, array of {company_id?, company_name?, priority?})
    class AddTargetCompanyTool < BaseTool
      def call(args:, tool_execution:)
        if args["companies"].is_a?(Array) || args[:companies].is_a?(Array)
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
        company = resolve_company(args)
        return { success: false, error: "Company not found" } if company.nil?

        utc = UserTargetCompany.find_or_initialize_by(user: user, company: company)
        if (args["priority"] || args[:priority]).present?
          utc.priority = (args["priority"] || args[:priority]).to_i
        end
        utc.save!

        {
          success: true,
          data: {
            company: { id: company.id, name: company.name },
            target_company: { id: utc.id, priority: utc.priority }
          }
        }
      end

      def add_many(args)
        items = args["companies"]
        items = args[:companies] if items.nil?
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

      def resolve_company(args)
        company_id = (args["company_id"] || args[:company_id]).to_i
        if company_id.positive?
          found = Company.find_by(id: company_id)
          return found if found
          # If the model provided an ID that doesn't exist in our DB, fall back to name-based lookup/creation.
        end

        name = (args["company_name"] || args[:company_name]).to_s.strip
        return nil if name.blank?

        Company.where("lower(name) = ?", name.downcase).first || Company.create!(name: name)
      end
    end
  end
end
