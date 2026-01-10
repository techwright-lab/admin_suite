# frozen_string_literal: true

require "test_helper"

class ResumeWorkExperienceSkillTest < ActiveSupport::TestCase
  test "validates uniqueness of skill_tag per resume_work_experience" do
    resume = create(:user_resume, :with_pdf_file)
    exp = ResumeWorkExperience.create!(
      user_resume: resume,
      company_name: "Acme",
      role_title: "Engineer",
      responsibilities: [],
      highlights: [],
      metadata: {}
    )
    skill = SkillTag.find_or_create_by_name("Ruby")

    ResumeWorkExperienceSkill.create!(resume_work_experience: exp, skill_tag: skill)

    dup = ResumeWorkExperienceSkill.new(resume_work_experience: exp, skill_tag: skill)
    assert_not dup.valid?
  end
end
