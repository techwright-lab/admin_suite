# frozen_string_literal: true

module Assistant
  module Tools
    # Write: add a company to the user's target companies list.
    #
    # args:
    # - company_id (optional)
    # - company_name (optional, used to find-or-create)
    # - priority (optional)
    class AddTargetCompanyTool < BaseTool
      def call(args:, tool_execution:)
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
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.record.errors.full_messages.join(", ") }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def resolve_company(args)
        company_id = (args["company_id"] || args[:company_id]).to_i
        return Company.find_by(id: company_id) if company_id.positive?

        name = (args["company_name"] || args[:company_name]).to_s.strip
        return nil if name.blank?

        Company.where("lower(name) = ?", name.downcase).first || Company.create!(name: name)
      end
    end
  end
end
