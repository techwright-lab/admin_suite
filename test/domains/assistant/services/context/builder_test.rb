# frozen_string_literal: true

require "test_helper"

module Assistant
  module Context
    class BuilderTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Jane Doe")
      end

      test "build returns all required sections" do
        result = Builder.new(user: @user, page_context: {}).build

        assert_includes result.keys, :user
        assert_includes result.keys, :career
        assert_includes result.keys, :skills
        assert_includes result.keys, :pipeline
        assert_includes result.keys, :page
      end

      test "user_summary includes basic user info" do
        result = Builder.new(user: @user, page_context: {}).build

        assert_equal @user.id, result[:user][:id]
        assert_equal @user.display_name, result[:user][:name]
        assert_not_nil result[:user][:email_verified]
        assert_not_nil result[:user][:created_at]
      end

      test "career_summary is nil when user has no resumes" do
        result = Builder.new(user: @user, page_context: {}).build

        # Career section exists but resume is nil
        assert_not_nil result[:career]
        assert_nil result[:career][:resume]
      end

      test "career_summary includes resume summary when user has analyzed resume" do
        resume = create(:user_resume, :with_pdf_file,
          user: @user,
          analysis_status: :completed,
          analyzed_at: 1.day.ago,
          analysis_summary: "Experienced backend developer",
          extracted_data: {
            "resume_extraction" => {
              "parsed" => {
                "strengths" => [ "Problem solving", "Leadership", "Communication" ],
                "domains" => [ "FinTech", "SaaS", "E-commerce" ]
              }
            }
          }
        )

        result = Builder.new(user: @user, page_context: {}).build

        assert_not_nil result[:career][:resume]
        assert_equal "Experienced backend developer", result[:career][:resume][:profile_summary]
        assert_equal [ "Problem solving", "Leadership", "Communication" ], result[:career][:resume][:strengths]
        assert_equal [ "FinTech", "SaaS", "E-commerce" ], result[:career][:resume][:domains]
        assert_equal 1, result[:career][:resume][:resume_count]
        assert_nil result[:career][:resume][:full_text], "Full text should not be included by default"
      end

      test "career_summary includes full resume text when include_full_resume is true" do
        resume = create(:user_resume, :with_pdf_file,
          user: @user,
          analysis_status: :completed,
          analyzed_at: 1.day.ago,
          analysis_summary: "Experienced developer",
          parsed_text: "Full resume text content here"
        )

        result = Builder.new(user: @user, page_context: { include_full_resume: true }).build

        assert_equal "Full resume text content here", result[:career][:resume][:full_text]
      end

      test "career_summary includes full resume text when resume_id is in page_context" do
        resume = create(:user_resume, :with_pdf_file,
          user: @user,
          analysis_status: :completed,
          analyzed_at: 1.day.ago,
          analysis_summary: "Experienced developer",
          parsed_text: "My resume content"
        )

        result = Builder.new(user: @user, page_context: { resume_id: resume.id }).build

        assert_equal "My resume content", result[:career][:resume][:full_text]
      end

      test "work_history_summary includes user work experiences" do
        exp1 = create(:user_work_experience,
          user: @user,
          role_title: "Senior Engineer",
          company_name: "TechCorp",
          current: true,
          end_date: nil,
          start_date: 2.years.ago,
          highlights: [ "Led team", "Shipped features" ]
        )
        exp2 = create(:user_work_experience,
          user: @user,
          role_title: "Junior Engineer",
          company_name: "StartupCo",
          current: false,
          start_date: 4.years.ago,
          end_date: 2.years.ago,
          highlights: [ "Built APIs" ]
        )

        result = Builder.new(user: @user, page_context: {}).build

        work_history = result[:career][:work_history]
        assert_not_nil work_history
        assert_equal 2, work_history.size

        # Should be reverse chronological (current job first)
        current_job = work_history.find { |w| w[:current] == true }
        assert_not_nil current_job
        assert_equal "Senior Engineer", current_job[:title]
        assert_equal "TechCorp", current_job[:company]
        assert_equal "Present", current_job[:end_date]
        assert_includes current_job[:highlights], "Led team"
      end

      test "work_history_summary limits to MAX_WORK_EXPERIENCES" do
        6.times do |i|
          create(:user_work_experience,
            user: @user,
            role_title: "Role #{i}",
            company_name: "Company #{i}",
            start_date: (i + 1).years.ago
          )
        end

        result = Builder.new(user: @user, page_context: {}).build

        work_history = result[:career][:work_history]
        assert_equal Builder::MAX_WORK_EXPERIENCES, work_history.size
      end

      test "targets_summary includes target roles, companies, and domains" do
        role = create(:job_role, title: "Staff Engineer")
        company = create(:company, name: "Google")
        domain = create(:domain, name: "AI/ML")

        @user.target_job_roles << role
        @user.target_companies << company
        @user.target_domains << domain if @user.respond_to?(:target_domains)

        result = Builder.new(user: @user, page_context: {}).build

        targets = result[:career][:targets]
        assert_not_nil targets
        assert_includes targets[:roles], "Staff Engineer"
        assert_includes targets[:companies], "Google"
      end

      test "targets_summary is nil when user has no targets" do
        result = Builder.new(user: @user, page_context: {}).build

        assert_nil result[:career][:targets]
      end

      test "pipeline_summary includes interview applications" do
        company = create(:company, name: "Acme Inc")
        role = create(:job_role, title: "Engineer")
        app = create(:interview_application,
          user: @user,
          company: company,
          job_role: role,
          status: :active
        )

        result = Builder.new(user: @user, page_context: {}).build

        pipeline = result[:pipeline]
        assert_equal 1, pipeline[:interview_applications_count]
        assert_equal 1, pipeline[:recent_interview_applications].size

        recent_app = pipeline[:recent_interview_applications].first
        assert_equal app.id, recent_app[:id]
        assert_equal "Acme Inc", recent_app[:company]
        assert_equal "Engineer", recent_app[:job_role]
      end

      test "page_summary includes page context fields" do
        context = {
          job_listing_id: 123,
          interview_application_id: 456,
          opportunity_id: 789,
          resume_id: 101
        }

        result = Builder.new(user: @user, page_context: context).build

        assert_equal 123, result[:page][:job_listing_id]
        assert_equal 456, result[:page][:interview_application_id]
        assert_equal 789, result[:page][:opportunity_id]
        assert_equal 101, result[:page][:resume_id]
      end

      test "page_summary excludes nil values" do
        result = Builder.new(user: @user, page_context: { job_listing_id: nil }).build

        assert_not_includes result[:page].keys, :job_listing_id
      end

      test "handles resume with string extracted_data" do
        resume = create(:user_resume, :with_pdf_file,
          user: @user,
          analysis_status: :completed,
          analyzed_at: 1.day.ago,
          analysis_summary: "Developer",
          extracted_data: '{"resume_extraction": {"parsed": {"strengths": ["Coding"]}}}'
        )

        result = Builder.new(user: @user, page_context: {}).build

        assert_not_nil result[:career][:resume]
        assert_equal [ "Coding" ], result[:career][:resume][:strengths]
      end

      test "handles resume with malformed extracted_data gracefully" do
        resume = create(:user_resume, :with_pdf_file,
          user: @user,
          analysis_status: :completed,
          analyzed_at: 1.day.ago,
          analysis_summary: "Developer",
          extracted_data: "not valid json {"
        )

        # Should not raise an error
        result = Builder.new(user: @user, page_context: {}).build

        assert_not_nil result[:career][:resume]
        assert_equal [], result[:career][:resume][:strengths]
      end

      test "skill_summary includes top skills" do
        skill = create(:skill_tag, name: "Ruby")
        user_skill = create(:user_skill,
          user: @user,
          skill_tag: skill,
          aggregated_level: 4.0
        )

        # Mock top_skills method with a method that returns the skill
        def @user.top_skills(limit:)
          user_skills.limit(limit)
        end

        result = Builder.new(user: @user, page_context: {}).build

        top_skills = result[:skills][:top_skills]
        assert_equal 1, top_skills.size
        assert_equal "Ruby", top_skills.first[:name]
      end
    end
  end
end
