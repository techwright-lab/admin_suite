# frozen_string_literal: true

FactoryBot.define do
  factory :connected_account do
    association :user
    provider { "google_oauth2" }
    sequence(:uid) { |n| "google_uid_#{n}" }
    access_token { "mock_access_token_#{SecureRandom.hex(16)}" }
    refresh_token { "mock_refresh_token_#{SecureRandom.hex(16)}" }
    expires_at { 1.hour.from_now }
    scopes { "email profile https://www.googleapis.com/auth/gmail.readonly" }
    sequence(:email) { |n| "user#{n}@gmail.com" }
    sync_enabled { true }
    last_synced_at { nil }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :expiring_soon do
      expires_at { 2.minutes.from_now }
    end

    trait :sync_disabled do
      sync_enabled { false }
    end

    trait :recently_synced do
      last_synced_at { 5.minutes.ago }
    end

    trait :needs_reauth do
      needs_reauth { true }
      auth_error_at { 1.hour.ago }
      auth_error_message { "Token has been revoked" }
      sync_enabled { false }
    end
  end
end
