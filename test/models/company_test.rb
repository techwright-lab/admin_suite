# frozen_string_literal: true

require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "should create company with valid attributes" do
    company = Company.new(name: "Google")
    assert company.valid?
  end

  test "should require name" do
    company = Company.new
    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    create(:company, name: "Google")
    company = Company.new(name: "Google")
    assert_not company.valid?
    assert_includes company.errors[:name], "has already been taken"
  end

  test "should normalize name" do
    company = create(:company, name: "  Google  ")
    assert_equal "Google", company.name
  end

  test "should have display_name" do
    company = create(:company, name: "Google")
    assert_equal "Google", company.display_name
  end

  test "should check if has logo" do
    company = create(:company, logo_url: nil)
    assert_not company.has_logo?

    company.update(logo_url: "https://example.com/logo.png")
    assert company.has_logo?
  end

  test "should have associations" do
    company = create(:company)
    assert_respond_to company, :job_listings
    assert_respond_to company, :interview_applications
    assert_respond_to company, :users_with_current_company
    assert_respond_to company, :user_target_companies
    assert_respond_to company, :users_targeting
  end
end
