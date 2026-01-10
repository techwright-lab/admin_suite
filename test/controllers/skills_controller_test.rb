# frozen_string_literal: true

require "test_helper"

class SkillsControllerTest < ActionDispatch::IntegrationTest
  test "show renders skill detail for authenticated user" do
    user = create(:user)
    sign_in_as(user)

    skill = SkillTag.find_or_create_by_name("Ruby")
    user_skill = user.user_skills.create!(skill_tag: skill, aggregated_level: 4.0, category: "Backend", resume_count: 1)

    uwe = UserWorkExperience.create!(
      user: user,
      company_name: "Acme",
      role_title: "Engineer",
      responsibilities: [],
      highlights: [],
      merge_keys: {}
    )
    UserWorkExperienceSkill.create!(user_work_experience: uwe, skill_tag: skill, source_count: 1)

    get skill_path(skill.id)
    assert_response :success
    assert_includes response.body, "Ruby"
    assert_includes response.body, user_skill.aggregated_level.round(1).to_s
  end
end
