# frozen_string_literal: true

require "test_helper"

class UserWorkExperienceTest < ActiveSupport::TestCase
  test "display_company_name and display_role_title prefer associated records" do
    user = create(:user)
    company = create(:company, name: "Acme")
    role = create(:job_role, title: "Engineer")

    uwe = UserWorkExperience.create!(
      user: user,
      company: company,
      job_role: role,
      company_name: "Acme From Text",
      role_title: "Engineer From Text",
      responsibilities: [],
      highlights: [],
      merge_keys: {}
    )

    assert_equal "Acme", uwe.display_company_name
    assert_equal "Engineer", uwe.display_role_title
  end

  test "display_company_name and display_role_title fall back to stored text" do
    user = create(:user)

    uwe = UserWorkExperience.create!(
      user: user,
      company_name: "Acme",
      role_title: "Engineer",
      responsibilities: [],
      highlights: [],
      merge_keys: {}
    )

    assert_equal "Acme", uwe.display_company_name
    assert_equal "Engineer", uwe.display_role_title
  end
end
