require "test_helper"

class OauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auth_hash = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "123456789",
      info: OmniAuth::AuthHash::InfoHash.new(
        email: "oauth@example.com",
        name: "OAuth User"
      ),
      credentials: OmniAuth::AuthHash.new(
        token: "access_token_123",
        refresh_token: "refresh_token_123",
        expires_at: Time.current.to_i + 3600,
        scope: "email profile"
      )
    )
  end

  test "create signs in existing user by OAuth provider and uid" do
    user = create(:user, :oauth_user, oauth_provider: "google_oauth2", oauth_uid: "123456789", email_address: "oauth@example.com", terms_accepted: true)
    create(:connected_account, user: user, provider: "google_oauth2", uid: "123456789")

    OmniAuth.config.mock_auth[:google_oauth2] = @auth_hash

    get "/auth/google_oauth2/callback"

    assert_redirected_to dashboard_path
    # Check that session was created by verifying Current.user is set after redirect
    follow_redirect!
    assert_response :success
  end

  test "create signs up new user via OAuth" do
    assert_difference -> { User.count }, 1 do
      assert_difference -> { ConnectedAccount.count }, 1 do
        OmniAuth.config.mock_auth[:google_oauth2] = @auth_hash

        get "/auth/google_oauth2/callback"
      end
    end

    user = User.find_by(email_address: "oauth@example.com")
    assert_not_nil user
    assert_equal "google_oauth2", user.oauth_provider
    assert_equal "123456789", user.oauth_uid
    assert_not_nil user.email_verified_at
    assert_not_nil user.connected_accounts.find_by(provider: "google_oauth2", uid: "123456789")

    assert_redirected_to dashboard_path
    # Check that session was created by verifying Current.user is set after redirect
    follow_redirect!
    assert_response :success
  end

  test "create links OAuth to existing user by email" do
    user = create(:user, email_address: "oauth@example.com")

    assert_difference -> { ConnectedAccount.count }, 1 do
      OmniAuth.config.mock_auth[:google_oauth2] = @auth_hash

      get "/auth/google_oauth2/callback"
    end

    user.reload
    assert_equal "google_oauth2", user.oauth_provider
    assert_equal "123456789", user.oauth_uid
    assert_not_nil user.email_verified_at
    assert_not_nil user.connected_accounts.find_by(provider: "google_oauth2", uid: "123456789")

    assert_redirected_to dashboard_path
  end

  test "create connects account when user is already authenticated" do
    user = create(:user, email_verified_at: Time.current)
    sign_in_as(user)

    assert_difference -> { ConnectedAccount.count }, 1 do
      OmniAuth.config.mock_auth[:google_oauth2] = @auth_hash

      get "/auth/google_oauth2/callback"
    end

    account = user.reload.connected_accounts.find_by(provider: "google_oauth2", uid: "123456789")
    assert_not_nil account
    assert_equal "oauth@example.com", account.email

    assert_redirected_to settings_path(tab: "integrations")
  end

  test "create allows multiple Google accounts per user" do
    user = create(:user, email_verified_at: Time.current)
    sign_in_as(user)
    create(:connected_account, user: user, provider: "google_oauth2", uid: "first_uid", email: "first@example.com")

    @auth_hash.uid = "second_uid"
    @auth_hash.info.email = "second@example.com"
    OmniAuth.config.mock_auth[:google_oauth2] = @auth_hash

    assert_difference -> { ConnectedAccount.count }, 1 do
      get "/auth/google_oauth2/callback"
    end

    assert_equal 2, user.reload.connected_accounts.google.count
    assert_redirected_to settings_path(tab: "integrations")
  end

  test "failure redirects to appropriate path" do
    get "/auth/failure", params: { message: "access_denied", strategy: "google_oauth2" }

    assert_redirected_to new_session_path
  end

  test "failure redirects authenticated users to settings" do
    user = create(:user, email_verified_at: Time.current)
    sign_in_as(user)

    get "/auth/failure", params: { message: "access_denied", strategy: "google_oauth2" }

    assert_redirected_to settings_path(tab: "integrations")
  end
end
