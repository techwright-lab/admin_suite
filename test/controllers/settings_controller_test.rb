# frozen_string_literal: true

require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, :with_complete_profile, email_verified_at: Time.current)
    sign_in_as(@user)
  end

  test "should get show" do
    get settings_url
    assert_response :success
  end

  test "should get show with tab parameter" do
    %w[profile general notifications ai_preferences integrations security privacy].each do |tab|
      get settings_url(tab: tab)
      assert_response :success
    end
  end

  test "should update profile" do
    patch update_profile_settings_url, params: {
      user: {
        name: "Updated Name",
        bio: "Updated bio",
        years_of_experience: 10
      }
    }

    assert_redirected_to settings_path(tab: "profile")
    @user.reload
    assert_equal "Updated Name", @user.name
    assert_equal "Updated bio", @user.bio
    assert_equal 10, @user.years_of_experience
  end

  test "should update general settings" do
    patch update_general_settings_url, params: {
      user_preference: {
        theme: "dark",
        timezone: "America/New_York",
        preferred_view: "table"
      }
    }

    assert_redirected_to settings_path(tab: "general")
    @user.preference.reload
    assert_equal "dark", @user.preference.theme
    assert_equal "America/New_York", @user.preference.timezone
    assert_equal "table", @user.preference.preferred_view
  end

  test "should update notification settings" do
    patch update_notifications_settings_url, params: {
      user_preference: {
        email_notifications: false,
        email_weekly_digest: true,
        email_interview_reminders: false
      }
    }

    assert_redirected_to settings_path(tab: "notifications")
    @user.preference.reload
    assert_equal false, @user.preference.email_notifications
    assert_equal true, @user.preference.email_weekly_digest
    assert_equal false, @user.preference.email_interview_reminders
  end

  test "should update AI preferences" do
    patch update_ai_preferences_settings_url, params: {
      user_preference: {
        ai_summary_enabled: false,
        ai_feedback_analysis: true,
        ai_interview_prep: false,
        ai_insights_frequency: "daily"
      }
    }

    assert_redirected_to settings_path(tab: "ai_preferences")
    @user.preference.reload
    assert_equal false, @user.preference.ai_summary_enabled
    assert_equal true, @user.preference.ai_feedback_analysis
    assert_equal false, @user.preference.ai_interview_prep
    assert_equal "daily", @user.preference.ai_insights_frequency
  end

  test "should update privacy settings" do
    patch update_privacy_settings_url, params: {
      user_preference: {
        data_retention_days: 365
      }
    }

    assert_redirected_to settings_path(tab: "privacy")
    @user.preference.reload
    assert_equal 365, @user.preference.data_retention_days
  end

  test "should update security settings with valid password" do
    patch update_security_settings_url, params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to settings_path(tab: "security")
  end

  test "should destroy other session" do
    other_session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "192.168.1.1"
    )

    assert_difference "@user.sessions.count", -1 do
      delete revoke_session_settings_url(session_id: other_session.id)
    end

    assert_redirected_to settings_path(tab: "security")
  end

  test "should destroy all other sessions" do
    2.times do |i|
      @user.sessions.create!(
        user_agent: "Test Browser #{i}",
        ip_address: "192.168.1.#{i}"
      )
    end

    delete destroy_all_sessions_settings_url

    assert_redirected_to settings_path(tab: "security")
    # Should keep only the current session
    assert_equal 1, @user.sessions.count
  end

  test "should disconnect provider" do
    connected_account = create(:connected_account, user: @user)

    assert_difference "@user.connected_accounts.count", -1 do
      delete disconnect_provider_settings_url(provider: "google_oauth2")
    end

    assert_redirected_to settings_path(tab: "integrations")
  end

  test "should export data" do
    post export_data_settings_url

    assert_redirected_to settings_path(tab: "privacy")
    assert_match /export/, flash[:notice].downcase
  end

  test "should not destroy account with wrong password" do
    delete account_settings_url, params: { password: "wrongpassword" }

    assert_redirected_to settings_path(tab: "privacy")
    assert_match /incorrect/i, flash[:alert]
    assert User.exists?(@user.id)
  end
end
