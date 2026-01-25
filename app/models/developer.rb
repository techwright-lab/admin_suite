# frozen_string_literal: true

# Developer model for TechWright SSO authenticated users
#
# Stores developer accounts that can access the internal admin portal.
# Completely separate from the User model - developers authenticate
# via TechWright SSO and don't need a User account.
#
# @example Finding or creating a developer from OAuth
#   developer = Developer.find_or_create_from_omniauth(auth)
#   developer.record_login!(ip_address: request.remote_ip)
#
class Developer < ApplicationRecord
  # Encrypt sensitive OAuth tokens at rest
  encrypts :access_token, :refresh_token

  # Validations
  validates :techwright_uid, presence: true, uniqueness: true
  validates :email, presence: true

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :recently_active, -> { where("last_login_at > ?", 30.days.ago) }

  # Finds or creates a Developer from OmniAuth authentication data
  #
  # @param auth [OmniAuth::AuthHash] The OAuth authentication data from TechWright
  # @return [Developer] The found or created developer record
  def self.find_or_create_from_omniauth(auth)
    developer = find_or_initialize_by(techwright_uid: auth.uid)
    developer.update!(
      email: auth.info.email,
      name: auth.info.name,
      avatar_url: auth.info.image,
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      token_expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil
    )
    developer
  end

  # Records a login event for audit purposes
  #
  # @param ip_address [String] The IP address of the login request
  # @return [Boolean] True if the update was successful
  def record_login!(ip_address:)
    update!(
      last_login_at: Time.current,
      last_login_ip: ip_address,
      login_count: (login_count || 0) + 1
    )
  end

  # Checks if the developer account is enabled
  #
  # @return [Boolean] True if the developer can access the admin portal
  def enabled?
    enabled
  end

  # Checks if the OAuth token has expired
  #
  # @return [Boolean] True if the token has expired or will expire within 5 minutes
  def token_expired?
    return true if token_expires_at.nil?

    token_expires_at < 5.minutes.from_now
  end
end
