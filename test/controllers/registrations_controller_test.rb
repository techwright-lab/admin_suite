require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid attributes" do
    assert_difference -> { User.count }, 1 do
      post registrations_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          terms_accepted: true
        }
      }
    end

    user = User.find_by(email_address: "newuser@example.com")
    assert_not_nil user
    assert_nil user.email_verified_at
    assert_enqueued_email_with UserMailer, :verify_email, args: [user]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_response :success
    # Check for flash notice about email verification
    assert_match /check your email/i, response.body
  end

  test "create with invalid email" do
    create(:user, email_address: "existing@example.com")

    assert_no_difference -> { User.count } do
      post registrations_path, params: {
        user: {
          email_address: "existing@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with mismatched passwords" do
    assert_no_difference -> { User.count } do
      post registrations_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create sends verification email" do
    post registrations_path, params: {
      user: {
        email_address: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        terms_accepted: true
      }
    }

    user = User.find_by(email_address: "newuser@example.com")
    assert_not_nil user
    assert_enqueued_email_with UserMailer, :verify_email, args: [user]
  end
end

