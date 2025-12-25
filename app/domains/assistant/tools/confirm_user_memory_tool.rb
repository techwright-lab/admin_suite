# frozen_string_literal: true

module Assistant
  module Tools
    # Confirms a memory proposal and persists selected items into long-term memory.
    class ConfirmUserMemoryTool < BaseTool
      # args:
      # - proposal_id: integer
      # - accepted_keys: array[string]
      def call(args:, tool_execution:)
        proposal_id = args["proposal_id"] || args[:proposal_id]
        accepted_keys = Array(args["accepted_keys"] || args[:accepted_keys]).map(&:to_s)

        proposal = Assistant::Memory::MemoryProposal.find_by(id: proposal_id, user: user)
        return { success: false, error: "Proposal not found" } if proposal.nil?
        return { success: false, error: "Proposal is not pending" } unless proposal.status == "pending"

        items = Array(proposal.proposed_items)
        accepted = items.select { |i| accepted_keys.include?(i["key"].to_s) }
        rejected = items.reject { |i| accepted_keys.include?(i["key"].to_s) }

        ActiveRecord::Base.transaction do
          accepted.each do |item|
            key = item["key"].to_s
            value = item["value"].is_a?(Hash) ? item["value"] : { "value" => item["value"] }

            record = Assistant::Memory::UserMemory.find_or_initialize_by(user: user, key: key)
            record.value = value
            record.source = "user"
            record.confidence = 1.0
            record.last_confirmed_at = Time.current
            record.save!
          end

          proposal.update!(
            status: "accepted",
            confirmed_at: Time.current,
            confirmed_by: user
          )
        end

        {
          success: true,
          data: {
            accepted: accepted.map { |i| i["key"] },
            rejected: rejected.map { |i| i["key"] }
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
