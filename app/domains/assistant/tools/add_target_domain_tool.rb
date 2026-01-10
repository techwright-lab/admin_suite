# frozen_string_literal: true

module Assistant
  module Tools
    # Write: add a domain to the user's target domains list.
    #
    # args:
    # - domain_id (optional)
    # - domain_name (optional, used to find-or-create)
    # - priority (optional)
    # - domains (optional, array of {domain_id?, domain_name?, priority?})
    class AddTargetDomainTool < BaseTool
      def call(args:, tool_execution:)
        if args["domains"].is_a?(Array) || args[:domains].is_a?(Array)
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
        domain = resolve_domain(args)
        return { success: false, error: "Domain not found or could not be created" } if domain.nil?

        utd = UserTargetDomain.find_or_initialize_by(user: user, domain: domain)
        if (args["priority"] || args[:priority]).present?
          utd.priority = (args["priority"] || args[:priority]).to_i
        end
        utd.save!

        {
          success: true,
          data: {
            domain: { id: domain.id, name: domain.name },
            target_domain: { id: utd.id, priority: utd.priority }
          }
        }
      end

      def add_many(args)
        items = args["domains"]
        items = args[:domains] if items.nil?
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

      def resolve_domain(args)
        domain_id = (args["domain_id"] || args[:domain_id]).to_i
        if domain_id.positive?
          found = Domain.find_by(id: domain_id)
          return found if found
          # If the model provided an ID that doesn't exist in our DB, fall back to name-based lookup/creation.
        end

        name = (args["domain_name"] || args[:domain_name]).to_s.strip
        return nil if name.blank?

        Domain.where("lower(name) = ?", name.downcase).first || Domain.create!(name: name)
      end
    end
  end
end
