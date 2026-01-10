# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class UpdateProfileToolTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool = UpdateProfileTool.new(user: @user)
        @tool_execution = Assistant::ToolExecution.new
      end

      test "updates years_of_experience" do
        result = @tool.call(args: { "years_of_experience" => 10 }, tool_execution: @tool_execution)

        assert result[:success]
        assert_includes result[:data][:updated_attributes], :years_of_experience
        assert_equal 10, @user.reload.years_of_experience
      end

      test "updates current_company by name" do
        company_name = "NewCompany#{SecureRandom.hex(4)}"
        result = @tool.call(args: { "current_company_name" => company_name }, tool_execution: @tool_execution)

        assert result[:success]
        assert_includes result[:data][:updated_attributes], :current_company
        assert_equal company_name, @user.reload.current_company.name
      end

      test "updates current_job_role by title" do
        role_title = "NewRole#{SecureRandom.hex(4)}"
        result = @tool.call(args: { "current_job_role_title" => role_title }, tool_execution: @tool_execution)

        assert result[:success]
        assert_includes result[:data][:updated_attributes], :current_job_role
        assert_equal role_title, @user.reload.current_job_role.title
      end

      test "updates social URLs" do
        result = @tool.call(
          args: {
            "linkedin_url" => "https://linkedin.com/in/test",
            "github_url" => "https://github.com/test"
          },
          tool_execution: @tool_execution
        )

        assert result[:success]
        assert_includes result[:data][:updated_attributes], :linkedin_url
        assert_includes result[:data][:updated_attributes], :github_url
        assert_equal "https://linkedin.com/in/test", @user.reload.linkedin_url
        assert_equal "https://github.com/test", @user.reload.github_url
      end

      test "updates bio" do
        bio_text = "This is my bio"
        result = @tool.call(args: { "bio" => bio_text }, tool_execution: @tool_execution)

        assert result[:success]
        assert_includes result[:data][:updated_attributes], :bio
        assert_equal bio_text, @user.reload.bio
      end

      test "clears values with empty string" do
        @user.update!(linkedin_url: "https://linkedin.com/in/old")
        result = @tool.call(args: { "linkedin_url" => "" }, tool_execution: @tool_execution)

        assert result[:success]
        assert_nil @user.reload.linkedin_url
      end

      test "fails without any valid attributes" do
        result = @tool.call(args: {}, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "No valid attributes"
      end

      test "clamps years_of_experience to valid range" do
        result = @tool.call(args: { "years_of_experience" => 100 }, tool_execution: @tool_execution)

        assert result[:success]
        assert_equal 60, @user.reload.years_of_experience # Clamped to max
      end

      test "multiple updates in single call" do
        result = @tool.call(
          args: {
            "years_of_experience" => 5,
            "linkedin_url" => "https://linkedin.com/in/multi",
            "bio" => "Multi update test"
          },
          tool_execution: @tool_execution
        )

        assert result[:success]
        assert_equal 3, result[:data][:updated_attributes].length
        @user.reload
        assert_equal 5, @user.years_of_experience
        assert_equal "https://linkedin.com/in/multi", @user.linkedin_url
        assert_equal "Multi update test", @user.bio
      end
    end
  end
end
