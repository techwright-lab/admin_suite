# frozen_string_literal: true

require "test_helper"

class ResumeWorkExperienceTest < ActiveSupport::TestCase
  test "display_company_name and display_role_title prefer associated records" do
    resume = create(:user_resume, :with_pdf_file)
    company = create(:company, name: "Acme")
    role = create(:job_role, title: "Engineer")

    exp = ResumeWorkExperience.create!(
      user_resume: resume,
      company: company,
      job_role: role,
      company_name: "Acme From Text",
      role_title: "Engineer From Text",
      responsibilities: [],
      highlights: [],
      metadata: {}
    )

    assert_equal "Acme", exp.display_company_name
    assert_equal "Engineer", exp.display_role_title
  end

  test "display_company_name and display_role_title fall back to stored text" do
    resume = create(:user_resume, :with_pdf_file)

    exp = ResumeWorkExperience.create!(
      user_resume: resume,
      company_name: "Acme",
      role_title: "Engineer",
      responsibilities: [],
      highlights: [],
      metadata: {}
    )

    assert_equal "Acme", exp.display_company_name
    assert_equal "Engineer", exp.display_role_title
  end

  test "reverse_chronological orders by end_date/start_date desc" do
    resume = create(:user_resume, :with_pdf_file)

    older = ResumeWorkExperience.create!(
      user_resume: resume,
      company_name: "A",
      role_title: "R",
      start_date: Date.new(2020, 1, 1),
      end_date: Date.new(2021, 1, 1),
      responsibilities: [],
      highlights: [],
      metadata: {}
    )

    newer = ResumeWorkExperience.create!(
      user_resume: resume,
      company_name: "B",
      role_title: "R",
      start_date: Date.new(2022, 1, 1),
      end_date: Date.new(2023, 1, 1),
      responsibilities: [],
      highlights: [],
      metadata: {}
    )

    assert_equal [ newer.id, older.id ], resume.resume_work_experiences.reverse_chronological.pluck(:id)
  end
end
