# frozen_string_literal: true

module Assistant
  module Tools
    # Write: remove one or more domains from the user's target domains list.
    #
    # args:
    # - domain_id (optional)
    # - domain_name (optional, used to find)
    # - domains (optional, array of {domain_id?, domain_name?})
    class RemoveTargetDomainTool < BaseTool
      def call(args:, tool_execution:)
        if args["domains"].is_a?(Array) || args[:domains].is_a?(Array)
          return remove_many(args)
        end

        remove_one(args)
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def remove_one(args)
        domain = find_domain(args)
        return { success: false, error: "Domain not found" } if domain.nil?

        utd = UserTargetDomain.find_by(user: user, domain: domain)
        if utd
          utd.destroy!
          { success: true, data: { removed: true, domain: { id: domain.id, name: domain.name } } }
        else
          # Idempotent: "already removed" is a success.
          { success: true, data: { removed: false, domain: { id: domain.id, name: domain.name } } }
        end
      end

      def remove_many(args)
        items = args["domains"]
        items = args[:domains] if items.nil?
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

      def find_domain(args)
        domain_id = (args["domain_id"] || args[:domain_id]).to_i
        return Domain.find_by(id: domain_id) if domain_id.positive?

        name = (args["domain_name"] || args[:domain_name]).to_s.strip
        return nil if name.blank?

        Domain.where("lower(name) = ?", name.downcase).first
      end
    end
  end
end
