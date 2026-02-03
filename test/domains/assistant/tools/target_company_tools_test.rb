# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class TargetCompanyToolsTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new
      end

      test "list_target_companies returns success" do
        tool = ListTargetCompaniesTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:count].is_a?(Integer)
        assert result[:data][:target_companies].is_a?(Array)
      end

      test "add_target_company creates by name" do
        tool = AddTargetCompanyTool.new(user: @user)
        name = "TargetCo #{SecureRandom.hex(4)}"

        result = tool.call(args: { "company_name" => name }, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal name, result.dig(:data, :company, :name)
        assert @user.target_companies.where(name: name).exists?
      end

      test "add_target_company supports batch add" do
        tool = AddTargetCompanyTool.new(user: @user)
        companies = [
          { "company_name" => "BatchCo1 #{SecureRandom.hex(4)}" },
          { "company_name" => "BatchCo2 #{SecureRandom.hex(4)}" }
        ]

        result = tool.call(args: { "companies" => companies }, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal 2, result.dig(:data, :added_count)
      end

      test "remove_target_company is idempotent" do
        company = create(:company)
        tool = RemoveTargetCompanyTool.new(user: @user)

        result = tool.call(args: { "company_id" => company.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal false, result.dig(:data, :removed)
      end

      test "remove_target_company removes existing target" do
        company = create(:company)
        @user.user_target_companies.create!(company: company, priority: 1)
        tool = RemoveTargetCompanyTool.new(user: @user)

        result = tool.call(args: { "company_id" => company.id }, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal true, result.dig(:data, :removed)
        assert_not @user.target_companies.include?(company)
      end
    end
  end
end
