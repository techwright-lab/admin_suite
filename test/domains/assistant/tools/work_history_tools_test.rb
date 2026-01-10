# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class WorkHistoryToolsTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new
      end

      # ListWorkHistoryTool tests
      test "list_work_history returns success" do
        tool = ListWorkHistoryTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:count].is_a?(Integer)
        assert result[:data][:total_count].is_a?(Integer)
        assert result[:data][:work_history].is_a?(Array)
      end

      test "list_work_history respects limit" do
        tool = ListWorkHistoryTool.new(user: @user)
        result = tool.call(args: { "limit" => 2 }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:work_history].length <= 2
      end

      test "list_work_history includes skills by default" do
        # Create work experience with skills
        experience = @user.user_work_experiences.create!(
          company_name: "TestCompany",
          role_title: "TestRole",
          start_date: 1.year.ago
        )
        skill_tag = SkillTag.create!(name: "TestSkill#{SecureRandom.hex(4)}")
        experience.user_work_experience_skills.create!(skill_tag: skill_tag)

        tool = ListWorkHistoryTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        exp_data = result[:data][:work_history].find { |e| e[:id] == experience.id }
        assert exp_data.key?(:skills) if exp_data
      end

      test "list_work_history can exclude skills" do
        tool = ListWorkHistoryTool.new(user: @user)
        result = tool.call(args: { "include_skills" => false }, tool_execution: @tool_execution)

        assert result[:success]
        # Skills should not be included
        result[:data][:work_history].each do |exp|
          assert_not exp.key?(:skills)
        end
      end

      # GetWorkExperienceTool tests
      test "get_work_experience returns experience details" do
        experience = @user.user_work_experiences.create!(
          company_name: "DetailTestCompany",
          role_title: "DetailTestRole",
          start_date: 2.years.ago,
          end_date: 1.year.ago,
          highlights: ["Led team", "Improved performance"]
        )

        tool = GetWorkExperienceTool.new(user: @user)
        result = tool.call(args: { "experience_id" => experience.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal experience.id, result[:data][:id]
        assert_equal "DetailTestCompany", result[:data][:company][:name]
        assert_equal "DetailTestRole", result[:data][:role][:title]
        assert result[:data][:highlights].include?("Led team")
      end

      test "get_work_experience requires experience_id" do
        tool = GetWorkExperienceTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "experience_id"
      end

      test "get_work_experience fails for nonexistent experience" do
        tool = GetWorkExperienceTool.new(user: @user)
        result = tool.call(args: { "experience_id" => 999999 }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not found"
      end

      test "get_work_experience fails for other users experience" do
        other_user = create(:user, name: "Other User")
        experience = other_user.user_work_experiences.create!(
          company_name: "OtherCompany",
          role_title: "OtherRole",
          start_date: 1.year.ago
        )

        tool = GetWorkExperienceTool.new(user: @user)
        result = tool.call(args: { "experience_id" => experience.id }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not found"
      end
    end
  end
end
