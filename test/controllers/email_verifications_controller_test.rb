require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, :unverified)
  end

  test "show verifies email with valid token" do
    token = @user.generate_token_for(:email_verification)
    
    assert_changes -> { @user.reload.email_verified_at }, from: nil do
      get email_verification_path(token)
      assert_redirected_to new_session_path
    end

    assert_enqueued_email_with UserMailer, :welcome, args: [@user]
    
    follow_redirect!
    assert_response :success
    # Check flash message or response body
    assert_match /verified|email verified/i, response.body
  end

  test "show with invalid token redirects" do
    get email_verification_path("invalid_token")
    
    assert_redirected_to new_session_path
    
    follow_redirect!
    assert_response :success
    assert_match /invalid or has expired/i, response.body
  end

  test "show with expired token redirects" do
    # Create a token that's already expired (simulate by using old token)
    token = @user.generate_token_for(:email_verification)
    
    # Travel forward in time past expiration (24 hours)
    travel 25.hours do
      get email_verification_path(token)
      assert_redirected_to new_session_path
      
      follow_redirect!
      assert_response :success
      assert_match /invalid or has expired/i, response.body
    end
  end

  test "create resends verification email for unverified user" do
    post resend_email_verification_path, params: { email_address: @user.email_address }
    
    assert_enqueued_email_with UserMailer, :verify_email, args: [@user]
    assert_redirected_to new_session_path
    
    follow_redirect!
    assert_response :success
    assert_match /verification email sent/i, response.body
  end

  test "create does not resend for verified user" do
    @user.update!(email_verified_at: Time.current)
    
    post resend_email_verification_path, params: { email_address: @user.email_address }
    
    assert_enqueued_emails 0
    assert_redirected_to new_session_path
  end

  test "create handles non-existent email gracefully" do
    post resend_email_verification_path, params: { email_address: "nonexistent@example.com" }
    
    assert_enqueued_emails 0
    assert_redirected_to new_session_path
    
    follow_redirect!
    assert_response :success
    assert_match /verification email sent/i, response.body
  end
end

