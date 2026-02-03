# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class TargetJobRoleToolsTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new
      end

      test "list_target_job_roles returns success" do
        tool = ListTargetJobRolesTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:count].is_a?(Integer)
        assert result[:data][:target_job_roles].is_a?(Array)
      end

      test "add_target_job_role creates by title" do
        tool = AddTargetJobRoleTool.new(user: @user)
        title = "Target Role #{SecureRandom.hex(4)}"

        result = tool.call(args: { "job_role_title" => title }, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal title, result.dig(:data, :job_role, :title)
        assert @user.target_job_roles.where(title: title).exists?
      end

      test "add_target_job_role supports batch add" do
        tool = AddTargetJobRoleTool.new(user: @user)
        roles = [
          { "job_role_title" => "Batch Role 1 #{SecureRandom.hex(4)}" },
          { "job_role_title" => "Batch Role 2 #{SecureRandom.hex(4)}" }
        ]

        result = tool.call(args: { "job_roles" => roles }, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal 2, result.dig(:data, :added_count)
      end

      test "remove_target_job_role is idempotent" do
        job_role = create(:job_role)
        tool = RemoveTargetJobRoleTool.new(user: @user)

        result = tool.call(args: { "job_role_id" => job_role.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal false, result.dig(:data, :removed)
      end

      test "remove_target_job_role removes existing target" do
        job_role = create(:job_role)
        @user.user_target_job_roles.create!(job_role: job_role, priority: 1)
        tool = RemoveTargetJobRoleTool.new(user: @user)

        result = tool.call(args: { "job_role_id" => job_role.id }, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal true, result.dig(:data, :removed)
        assert_not @user.target_job_roles.include?(job_role)
      end
    end
  end
end
