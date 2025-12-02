# frozen_string_literal: true

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, :with_complete_profile)
    sign_in_as(@user)
  end

  test "should get show" do
    get profile_url
    assert_response :success
  end

  test "should display insights" do
    create_list(:interview, 3, :with_feedback, user: @user)
    
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

    assert_response :unprocessable_entity
  end
end

