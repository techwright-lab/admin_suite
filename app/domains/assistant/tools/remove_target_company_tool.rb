# frozen_string_literal: true

module Assistant
  module Tools
    # Write: remove one or more companies from the user's target companies list.
    #
    # args:
    # - company_id (optional)
    # - company_name (optional, used to find)
    # - companies (optional, array of {company_id?, company_name?})
    class RemoveTargetCompanyTool < BaseTool
      def call(args:, tool_execution:)
        if args["companies"].is_a?(Array) || args[:companies].is_a?(Array)
          return remove_many(args)
        end

        remove_one(args)
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def remove_one(args)
        company = find_company(args)
        return { success: false, error: "Company not found" } if company.nil?

        utc = UserTargetCompany.find_by(user: user, company: company)
        if utc
          utc.destroy!
          { success: true, data: { removed: true, company: { id: company.id, name: company.name } } }
        else
          # Idempotent: "already removed" is a success.
          { success: true, data: { removed: false, company: { id: company.id, name: company.name } } }
        end
      end

      def remove_many(args)
        items = args["companies"]
        items = args[:companies] if items.nil?
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

        successes = results.count { |r| r[:success] == true }
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

      def find_company(args)
        company_id = (args["company_id"] || args[:company_id]).to_i
        return Company.find_by(id: company_id) if company_id.positive?

        name = (args["company_name"] || args[:company_name]).to_s.strip
        return nil if name.blank?

        Company.where("lower(name) = ?", name.downcase).first
      end
    end
  end
end
