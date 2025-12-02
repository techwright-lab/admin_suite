require "test_helper"

class OauthAuthenticationServiceTest < ActiveSupport::TestCase
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

  test "finds user by OAuth provider and uid" do
    user = create(:user, :oauth_user, oauth_provider: "google_oauth2", oauth_uid: "123456789")
    
    service = OauthAuthenticationService.new(@auth_hash)
    result = service.run
    
    assert_equal user.id, result.id
  end

  test "finds user by email when OAuth provider doesn't match" do
    user = create(:user, email_address: "oauth@example.com")
    
    service = OauthAuthenticationService.new(@auth_hash)
    result = service.run
    
    assert_equal user.id, result.id
    assert_equal "google_oauth2", result.reload.oauth_provider
    assert_equal "123456789", result.oauth_uid
  end

  test "creates new user when none exists" do
    assert_difference -> { User.count }, 1 do
      service = OauthAuthenticationService.new(@auth_hash)
      result = service.run
      
      assert_equal "oauth@example.com", result.email_address
      assert_equal "OAuth User", result.name
      assert_equal "google_oauth2", result.oauth_provider
      assert_equal "123456789", result.oauth_uid
      assert_not_nil result.email_verified_at
    end
  end

  test "creates ConnectedAccount for Google OAuth" do
    assert_difference -> { ConnectedAccount.count }, 1 do
      service = OauthAuthenticationService.new(@auth_hash)
      user = service.run
      
      account = user.connected_accounts.find_by(provider: "google_oauth2", uid: "123456789")
      assert_not_nil account
      assert_equal "oauth@example.com", account.email
    end
  end

  test "does not create duplicate ConnectedAccount" do
    user = create(:user, :oauth_user, oauth_provider: "google_oauth2", oauth_uid: "123456789")
    create(:connected_account, user: user, provider: "google_oauth2", uid: "123456789")
    
    assert_no_difference -> { ConnectedAccount.count } do
      service = OauthAuthenticationService.new(@auth_hash)
      service.run
    end
  end

  test "updates OAuth fields for existing user without OAuth" do
    user = create(:user, email_address: "oauth@example.com", oauth_provider: nil, oauth_uid: nil)
    
    service = OauthAuthenticationService.new(@auth_hash)
    result = service.run
    
    assert_equal user.id, result.id
    assert_equal "google_oauth2", result.reload.oauth_provider
    assert_equal "123456789", result.oauth_uid
    assert_not_nil result.email_verified_at
  end

  test "does not update OAuth fields if already set" do
    user = create(:user, :oauth_user, oauth_provider: "google_oauth2", oauth_uid: "123456789")
    original_verified_at = user.email_verified_at
    
    service = OauthAuthenticationService.new(@auth_hash)
    result = service.run
    
    assert_equal original_verified_at, result.reload.email_verified_at
  end
end

