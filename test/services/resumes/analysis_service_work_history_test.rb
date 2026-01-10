# frozen_string_literal: true

require "test_helper"

class Resumes::AnalysisServiceWorkHistoryTest < ActiveSupport::TestCase
  test "analysis persists resume work experiences and per-experience skills" do
    resume = create(:user_resume, :completed, :with_pdf_file, parsed_text: nil, analysis_status: :pending, extracted_data: {})

    ai_result = {
      success: true,
      skills: [
        { name: "Ruby", category: "Backend", proficiency: 4, confidence: 0.8, evidence: "Rails", years: 5 }
      ],
      work_history: [
        {
          company: "Acme",
          role: "Engineer",
          duration: "2020-2021",
          start_date: Date.new(2020, 1, 1),
          end_date: Date.new(2021, 12, 31),
          current: false,
          responsibilities: [ "Built APIs" ],
          highlights: [ "Shipped X" ],
          skills_used: [ { name: "Ruby" }, { name: "PostgreSQL" } ]
        }
      ],
      summary: "Summary",
      confidence: 0.9,
      strengths: [],
      domains: [],
      resume_date: nil,
      resume_date_confidence: nil,
      resume_date_source: nil,
      provider: "openai",
      model: "gpt-test"
    }

    analysis = Resumes::AnalysisService.new(resume)
    analysis.define_singleton_method(:extract_text) { { success: true, text: "resume text", error: nil } }
    analysis.define_singleton_method(:extract_skills) { ai_result }
    analysis.define_singleton_method(:aggregate_user_skills) { true }

    result = analysis.run
    assert result[:success]

    resume.reload
    exp = resume.resume_work_experiences.first
    assert exp.present?
    assert_equal "Acme", exp.company_name
    assert_equal "Engineer", exp.role_title
    assert_equal Date.new(2020, 1, 1), exp.start_date
    assert_equal Date.new(2021, 12, 31), exp.end_date
    assert_equal false, exp.current
    assert_equal [ "Built APIs" ], exp.responsibilities
    assert_equal [ "Shipped X" ], exp.highlights

    skill_names = exp.skill_tags.order(:name).pluck(:name)
    assert_includes skill_names.map(&:downcase), "ruby"
    assert_includes skill_names.map(&:downcase), "postgresql"
  end
end
