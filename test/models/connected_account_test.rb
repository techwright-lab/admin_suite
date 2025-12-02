# frozen_string_literal: true

require "test_helper"

class ConnectedAccountTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "should be valid with required attributes" do
    account = build(:connected_account, user: @user)
    assert account.valid?
  end

  test "should require provider" do
    account = build(:connected_account, user: @user, provider: nil)
    assert_not account.valid?
    assert_includes account.errors[:provider], "can't be blank"
  end

  test "should require uid" do
    account = build(:connected_account, user: @user, uid: nil)
    assert_not account.valid?
    assert_includes account.errors[:uid], "can't be blank"
  end

  test "should validate provider inclusion" do
    account = build(:connected_account, user: @user, provider: "invalid_provider")
    assert_not account.valid?
    assert_includes account.errors[:provider], "is not included in the list"
  end

  test "should allow multiple accounts per user with different uids" do
    create(:connected_account, user: @user, provider: "google_oauth2", uid: "uid1")
    second_account = build(:connected_account, user: @user, provider: "google_oauth2", uid: "uid2")
    assert second_account.valid?
  end

  test "should not allow same provider and uid combination" do
    create(:connected_account, user: @user, provider: "google_oauth2", uid: "same_uid")
    other_user = create(:user)
    duplicate = build(:connected_account, user: other_user, provider: "google_oauth2", uid: "same_uid")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:provider], "account already connected to another user"
  end

  test "token_expired? returns true when token is expired" do
    account = build(:connected_account, expires_at: 1.hour.ago)
    assert account.token_expired?
  end

  test "token_expired? returns false when token is valid" do
    account = build(:connected_account, expires_at: 1.hour.from_now)
    assert_not account.token_expired?
  end

  test "token_expiring_soon? returns true when token expires within 5 minutes" do
    account = build(:connected_account, expires_at: 2.minutes.from_now)
    assert account.token_expiring_soon?
  end

  test "token_expiring_soon? returns false when token is valid for longer" do
    account = build(:connected_account, expires_at: 1.hour.from_now)
    assert_not account.token_expiring_soon?
  end

  test "refreshable? returns true when refresh_token exists" do
    account = build(:connected_account, refresh_token: "refresh_token")
    assert account.refreshable?
  end

  test "refreshable? returns false when refresh_token is nil" do
    account = build(:connected_account, refresh_token: nil)
    assert_not account.refreshable?
  end

  test "google? returns true for google_oauth2 provider" do
    account = build(:connected_account, provider: "google_oauth2")
    assert account.google?
  end

  test "mark_synced! updates last_synced_at" do
    account = create(:connected_account, user: @user)
    assert_nil account.last_synced_at

    account.mark_synced!
    assert_not_nil account.reload.last_synced_at
  end

  test "encrypts access_token" do
    account = create(:connected_account, user: @user, access_token: "sensitive_token")
    # Verify the token is encrypted in the database
    raw_value = ActiveRecord::Base.connection.execute(
      "SELECT access_token FROM connected_accounts WHERE id = #{account.id}"
    ).first["access_token"]
    
    assert_not_equal "sensitive_token", raw_value
    assert_equal "sensitive_token", account.access_token
  end
end

