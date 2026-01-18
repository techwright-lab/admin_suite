# frozen_string_literal: true

require "test_helper"

class InterviewRoundTypeTest < ActiveSupport::TestCase
  setup do
    @category = create(:category, kind: :job_role, name: "Engineering")
    @round_type = InterviewRoundType.create!(
      name: "Coding Interview",
      slug: "coding",
      description: "Live coding assessment",
      category: @category,
      position: 0
    )
  end

  test "validates presence of name" do
    round_type = InterviewRoundType.new(slug: "test")
    assert_not round_type.valid?
    assert_includes round_type.errors[:name], "can't be blank"
  end

  test "validates presence of slug" do
    round_type = InterviewRoundType.new(name: "Test")
    assert_not round_type.valid?
    assert_includes round_type.errors[:slug], "can't be blank"
  end

  test "validates uniqueness of slug" do
    duplicate = InterviewRoundType.new(
      name: "Another Coding",
      slug: "coding"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "normalizes slug" do
    round_type = InterviewRoundType.create!(
      name: "System Design",
      slug: "System Design"
    )
    assert_equal "system_design", round_type.slug
  end

  test "normalizes name" do
    round_type = InterviewRoundType.create!(
      name: "  Behavioral  ",
      slug: "behavioral"
    )
    assert_equal "Behavioral", round_type.name
  end

  test "universal? returns true when no category" do
    universal = InterviewRoundType.create!(
      name: "Phone Screen",
      slug: "phone_screen",
      category: nil
    )
    assert universal.universal?
    assert_not @round_type.universal?
  end

  test "for_department scope includes universal and department-specific" do
    universal = InterviewRoundType.create!(
      name: "Phone Screen",
      slug: "phone_screen_dept",
      category: nil
    )

    result = InterviewRoundType.for_department(@category.id)
    assert_includes result, universal
    assert_includes result, @round_type
  end

  test "department_name returns category name" do
    assert_equal "Engineering", @round_type.department_name

    universal = InterviewRoundType.create!(name: "Test", slug: "test_universal")
    assert_nil universal.department_name
  end

  test "find_by_slug works with various formats" do
    found = InterviewRoundType.find_by_slug("coding")
    assert_equal @round_type, found

    found = InterviewRoundType.find_by_slug("Coding")
    assert_equal @round_type, found
  end

  test "enabled and disabled scopes work with Disableable" do
    @round_type.disable!
    assert @round_type.disabled?

    assert_not_includes InterviewRoundType.enabled, @round_type
    assert_includes InterviewRoundType.disabled, @round_type

    @round_type.enable!
    assert_not @round_type.disabled?
    assert_includes InterviewRoundType.enabled, @round_type
  end

  test "has_many interview_rounds" do
    user = create(:user)
    company = create(:company)
    job_role = create(:job_role)
    application = create(:interview_application, user: user, company: company, job_role: job_role)
    round = create(:interview_round, interview_application: application, interview_round_type: @round_type)

    assert_includes @round_type.interview_rounds, round
  end
end
