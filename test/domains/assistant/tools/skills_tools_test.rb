# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class SkillsToolsTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new

        # Create some user skills for testing
        @skill_tag = SkillTag.find_or_create_by!(name: "TestSkill#{SecureRandom.hex(4)}")
        @user_skill = @user.user_skills.create!(
          skill_tag: @skill_tag,
          aggregated_level: 4.5,
          category: "Backend",
          confidence_score: 0.9,
          resume_count: 3
        )
      end

      # ListSkillsTool tests
      test "list_skills returns success" do
        tool = ListSkillsTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:count].is_a?(Integer)
        assert result[:data][:total_count].is_a?(Integer)
        assert result[:data][:skills].is_a?(Array)
      end

      test "list_skills respects limit" do
        tool = ListSkillsTool.new(user: @user)
        result = tool.call(args: { "limit" => 2 }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:skills].length <= 2
      end

      test "list_skills filters by category" do
        tool = ListSkillsTool.new(user: @user)
        result = tool.call(args: { "category" => "Backend" }, tool_execution: @tool_execution)

        assert result[:success]
        result[:data][:skills].each do |skill|
          assert_equal "Backend", skill[:category]
        end
      end

      test "list_skills filters strong skills" do
        # Create a developing skill
        weak_skill_tag = SkillTag.find_or_create_by!(name: "WeakSkill#{SecureRandom.hex(4)}")
        @user.user_skills.create!(
          skill_tag: weak_skill_tag,
          aggregated_level: 2.0,
          category: "Other"
        )

        tool = ListSkillsTool.new(user: @user)
        result = tool.call(args: { "filter" => "strong" }, tool_execution: @tool_execution)

        assert result[:success]
        result[:data][:skills].each do |skill|
          assert skill[:proficiency_level] >= 4.0
        end
      end

      test "list_skills includes categories list" do
        tool = ListSkillsTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:categories].is_a?(Array)
      end

      # GetSkillDetailsTool tests
      test "get_skill_details returns skill by id" do
        tool = GetSkillDetailsTool.new(user: @user)
        result = tool.call(args: { "skill_id" => @user_skill.id }, tool_execution: @tool_execution)

        assert result[:success], "Expected success but got: #{result[:error]}"
        assert_equal @user_skill.id, result[:data][:id]
        assert_equal @skill_tag.name, result[:data][:skill][:name]
        assert result[:data][:proficiency].present?
        assert result[:data][:evidence].present?
      end

      test "get_skill_details returns skill by name" do
        tool = GetSkillDetailsTool.new(user: @user)
        result = tool.call(args: { "skill_name" => @skill_tag.name }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal @user_skill.id, result[:data][:id]
      end

      test "get_skill_details is case insensitive for name" do
        tool = GetSkillDetailsTool.new(user: @user)
        result = tool.call(args: { "skill_name" => @skill_tag.name.upcase }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal @user_skill.id, result[:data][:id]
      end

      test "get_skill_details fails for nonexistent skill" do
        tool = GetSkillDetailsTool.new(user: @user)
        result = tool.call(args: { "skill_name" => "NonExistentSkill#{SecureRandom.hex(8)}" }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not found"
      end

      test "get_skill_details includes work experiences" do
        # Create work experience with this skill
        experience = @user.user_work_experiences.create!(
          company_name: "SkillTestCompany",
          role_title: "SkillTestRole",
          start_date: 1.year.ago
        )
        experience.user_work_experience_skills.create!(skill_tag: @skill_tag)

        tool = GetSkillDetailsTool.new(user: @user)
        result = tool.call(args: { "skill_id" => @user_skill.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:work_experiences].is_a?(Array)
        exp_data = result[:data][:work_experiences].find { |e| e[:company] == "SkillTestCompany" }
        assert exp_data.present?
      end
    end
  end
end
