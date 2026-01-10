# frozen_string_literal: true

require "test_helper"

class UserWorkExperienceSkillTest < ActiveSupport::TestCase
  test "validates uniqueness of skill_tag per user_work_experience" do
    user = create(:user)
    uwe = UserWorkExperience.create!(
      user: user,
      company_name: "Acme",
      role_title: "Engineer",
      responsibilities: [],
      highlights: [],
      merge_keys: {}
    )
    skill = SkillTag.find_or_create_by_name("Ruby")

    UserWorkExperienceSkill.create!(user_work_experience: uwe, skill_tag: skill, source_count: 1)

    dup = UserWorkExperienceSkill.new(user_work_experience: uwe, skill_tag: skill, source_count: 1)
    assert_not dup.valid?
  end
end
