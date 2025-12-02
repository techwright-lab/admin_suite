# frozen_string_literal: true

# ConnectedAccount model for storing OAuth credentials from external providers
# Supports Gmail, and future integrations like LinkedIn, Outlook
class ConnectedAccount < ApplicationRecord
  PROVIDERS = %w[google_oauth2].freeze

  belongs_to :user

  has_many :synced_emails, dependent: :destroy

  # Encrypt sensitive token data at rest
  encrypts :access_token, deterministic: false
  encrypts :refresh_token, deterministic: false

  # Validations
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :uid, presence: true
  # Allow multiple accounts per user (removed user_id+provider uniqueness)
  # But prevent same Google account (provider+uid) from being connected to multiple users
  validates :provider, uniqueness: { scope: :uid, message: "account already connected to another user" }

  # Scopes
  scope :google, -> { where(provider: "google_oauth2") }
  scope :sync_enabled, -> { where(sync_enabled: true) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :valid_tokens, -> { where("expires_at > ? OR expires_at IS NULL", Time.current) }

  # Checks if the access token is expired
  # @return [Boolean]
  def token_expired?
    expires_at.present? && expires_at < Time.current
  end

  # Checks if the token will expire soon (within 5 minutes)
  # @return [Boolean]
  def token_expiring_soon?
    expires_at.present? && expires_at < 5.minutes.from_now
  end

  # Checks if we can refresh the token
  # @return [Boolean]
  def refreshable?
    refresh_token.present?
  end

  # Returns true if this is a Google account
  # @return [Boolean]
  def google?
    provider == "google_oauth2"
  end

  # Updates tokens from OAuth response
  # @param auth [OmniAuth::AuthHash] The OAuth response
  # @return [Boolean]
  def update_from_oauth(auth)
    update(
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token || refresh_token,
      expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil,
      email: auth.info.email
    )
  end

  # Creates or updates a connected account from OAuth response
  # @param user [User] The user to connect
  # @param auth [OmniAuth::AuthHash] The OAuth response
  # @return [ConnectedAccount]
  def self.from_oauth(user, auth)
    account = user.connected_accounts.find_or_initialize_by(
      provider: auth.provider,
      uid: auth.uid
    )

    account.assign_attributes(
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token || account.refresh_token,
      expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil,
      email: auth.info.email,
      scopes: auth.credentials.scope
    )

    account.save!
    account
  end

  # Mark the account as synced
  # @return [Boolean]
  def mark_synced!
    update(last_synced_at: Time.current)
  end
end
