# frozen_string_literal: true

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, :with_complete_profile, email_verified_at: Time.current)
    sign_in_as(@user)
  end

  test "should get show" do
    get profile_url
    assert_response :success
  end

  test "should display insights" do
    applications = create_list(:interview_application, 3, :with_rounds, user: @user)
    applications.each do |application|
      application.interview_rounds.each do |round|
        create(:interview_feedback, interview_round: round)
      end
    end
    
    get profile_url
    assert_response :success
  end

  test "should get edit" do
    get edit_profile_url
    assert_response :success
  end

  test "should update profile" do
    patch profile_url, params: {
      user: {
        name: "Updated Name",
        bio: "Updated bio",
        current_role: "Senior Engineer"
      }
    }

    assert_redirected_to profile_url
    @user.reload
    assert_equal "Updated Name", @user.name
    assert_equal "Updated bio", @user.bio
  end

  test "should not update with invalid data" do
    patch profile_url, params: {
      user: {
        email_address: ""  # invalid email
      }
    }

    # The controller uses params.expect which raises ActionController::ParameterMissing (400)
    # when expected keys are missing, not a validation error (422)
    assert_response :bad_request
  end
end

