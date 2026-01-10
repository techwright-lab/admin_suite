# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class TargetDomainToolsTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new
      end

      # ListTargetDomainsTool tests
      test "list_target_domains returns success" do
        tool = ListTargetDomainsTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:count].is_a?(Integer)
        assert result[:data][:target_domains].is_a?(Array)
      end

      test "list_target_domains respects limit" do
        tool = ListTargetDomainsTool.new(user: @user)
        result = tool.call(args: { "limit" => 2 }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:target_domains].length <= 2
      end

      # AddTargetDomainTool tests
      test "add_target_domain creates domain by name" do
        tool = AddTargetDomainTool.new(user: @user)
        domain_name = "TestDomain#{SecureRandom.hex(4)}"

        result = tool.call(args: { "domain_name" => domain_name }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal domain_name, result[:data][:domain][:name]
        assert result[:data][:target_domain][:id].present?

        # Verify domain was created
        domain = Domain.find_by(name: domain_name)
        assert domain.present?
        assert @user.target_domains.include?(domain)
      end

      test "add_target_domain handles existing domain" do
        domain = Domain.create!(name: "ExistingDomain#{SecureRandom.hex(4)}")
        tool = AddTargetDomainTool.new(user: @user)

        result = tool.call(args: { "domain_id" => domain.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal domain.id, result[:data][:domain][:id]
      end

      test "add_target_domain supports batch add" do
        tool = AddTargetDomainTool.new(user: @user)
        domains = [
          { "domain_name" => "BatchDomain1#{SecureRandom.hex(4)}" },
          { "domain_name" => "BatchDomain2#{SecureRandom.hex(4)}" }
        ]

        result = tool.call(args: { "domains" => domains }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal 2, result[:data][:added_count]
      end

      test "add_target_domain fails without name or id" do
        tool = AddTargetDomainTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert_not result[:success]
        assert result[:error].present?
      end

      # RemoveTargetDomainTool tests
      test "remove_target_domain removes existing target" do
        domain = Domain.create!(name: "ToRemove#{SecureRandom.hex(4)}")
        @user.user_target_domains.create!(domain: domain)

        tool = RemoveTargetDomainTool.new(user: @user)
        result = tool.call(args: { "domain_id" => domain.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:removed]
        assert_not @user.target_domains.include?(domain)
      end

      test "remove_target_domain is idempotent" do
        domain = Domain.create!(name: "NotTargeted#{SecureRandom.hex(4)}")
        tool = RemoveTargetDomainTool.new(user: @user)

        result = tool.call(args: { "domain_id" => domain.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert_not result[:data][:removed] # Already not targeted
      end

      test "remove_target_domain fails for nonexistent domain" do
        tool = RemoveTargetDomainTool.new(user: @user)
        result = tool.call(args: { "domain_name" => "NonExistent#{SecureRandom.hex(8)}" }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not found"
      end
    end
  end
end
