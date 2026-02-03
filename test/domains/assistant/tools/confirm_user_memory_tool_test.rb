# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class ConfirmUserMemoryToolTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new
        @thread = Assistant::ChatThread.create!(user: @user, status: "open", title: nil, last_activity_at: Time.current)
      end

      test "confirm_user_memory persists accepted keys and marks proposal accepted" do
        proposal = Assistant::Memory::MemoryProposal.create!(
          thread: @thread,
          user: @user,
          trace_id: SecureRandom.uuid,
          status: "pending",
          proposed_items: [
            { "key" => "preferred_role", "value" => { "title" => "Staff Engineer" } },
            { "key" => "preferred_location", "value" => "Remote" }
          ]
        )

        tool = ConfirmUserMemoryTool.new(user: @user)
        result = tool.call(
          args: { "proposal_id" => proposal.id, "accepted_keys" => [ "preferred_role" ] },
          tool_execution: @tool_execution
        )

        assert result[:success], result[:error]
        assert_equal [ "preferred_role" ], result.dig(:data, :accepted)
        assert_equal [ "preferred_location" ], result.dig(:data, :rejected)

        proposal.reload
        assert_equal "accepted", proposal.status

        mem = Assistant::Memory::UserMemory.find_by(user: @user, key: "preferred_role")
        assert mem.present?
        assert_equal({ "title" => "Staff Engineer" }, mem.value)
      end

      test "confirm_user_memory fails when proposal is not pending" do
        proposal = Assistant::Memory::MemoryProposal.create!(
          thread: @thread,
          user: @user,
          trace_id: SecureRandom.uuid,
          status: "accepted",
          proposed_items: []
        )

        tool = ConfirmUserMemoryTool.new(user: @user)
        result = tool.call(args: { "proposal_id" => proposal.id, "accepted_keys" => [] }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not pending"
      end
    end
  end
end
