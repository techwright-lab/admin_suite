# frozen_string_literal: true

require "test_helper"

class JobRoleTest < ActiveSupport::TestCase
  test "should create job role with valid attributes" do
    job_role = JobRole.new(title: "Senior Software Engineer")
    assert job_role.valid?
  end

  test "should require title" do
    job_role = JobRole.new
    assert_not job_role.valid?
    assert_includes job_role.errors[:title], "can't be blank"
  end

  test "should require unique title" do
    create(:job_role, title: "Senior Software Engineer")
    job_role = JobRole.new(title: "Senior Software Engineer")
    assert_not job_role.valid?
    assert_includes job_role.errors[:title], "has already been taken"
  end

  test "should normalize title" do
    job_role = create(:job_role, title: "  Senior Engineer  ")
    assert_equal "Senior Engineer", job_role.title
  end

  test "should have display_name" do
    job_role = create(:job_role, title: "Senior Software Engineer")
    assert_equal "Senior Software Engineer", job_role.display_name
  end

  test "should return categories" do
    create(:job_role, category: "Engineering")
    create(:job_role, category: "Product")
    create(:job_role, category: "Engineering")

    categories = JobRole.categories
    assert_includes categories, "Engineering"
    assert_includes categories, "Product"
    assert_equal 2, categories.uniq.length
  end

  test "should have associations" do
    job_role = create(:job_role)
    assert_respond_to job_role, :job_listings
    assert_respond_to job_role, :interview_applications
    assert_respond_to job_role, :users_with_current_role
    assert_respond_to job_role, :user_target_job_roles
    assert_respond_to job_role, :users_targeting
  end
end
