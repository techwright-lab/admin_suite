# frozen_string_literal: true

require "test_helper"

class UserWorkExperienceSourceTest < ActiveSupport::TestCase
  test "validates uniqueness of resume_work_experience per user_work_experience" do
    user = create(:user)
    resume = create(:user_resume, :with_pdf_file, user: user, analysis_status: :completed, analyzed_at: Time.current)

    rwe = ResumeWorkExperience.create!(
      user_resume: resume,
      company_name: "Acme",
      role_title: "Engineer",
      responsibilities: [],
      highlights: [],
      metadata: {}
    )

    uwe = UserWorkExperience.create!(
      user: user,
      company_name: "Acme",
      role_title: "Engineer",
      responsibilities: [],
      highlights: [],
      merge_keys: {}
    )

    UserWorkExperienceSource.create!(user_work_experience: uwe, resume_work_experience: rwe)

    dup = UserWorkExperienceSource.new(user_work_experience: uwe, resume_work_experience: rwe)
    assert_not dup.valid?
  end
end
