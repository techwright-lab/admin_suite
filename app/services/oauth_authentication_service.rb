# frozen_string_literal: true

# Service for authenticating or creating a user from OAuth data
#
# @example
#   service = OauthAuthenticationService.new(auth_hash)
#   user = service.run
#
class OauthAuthenticationService
  # Initialize the service with OAuth authentication hash
  #
  # @param [OmniAuth::AuthHash] auth_hash The OAuth authentication data
  def initialize(auth_hash)
    @auth = auth_hash
    @provider = auth_hash.provider
    @uid = auth_hash.uid
    @email = auth_hash.info.email
    @name = auth_hash.info.name
  end

  # Runs the service to find or create a user from OAuth data
  #
  # @return [User] The authenticated or created user
  # @raise [ActiveRecord::RecordInvalid] If user creation fails
  def run
    user = find_user_by_oauth || find_user_by_email || create_user
    update_oauth_fields(user) unless user.oauth_provider.present?

    # Create ConnectedAccount for Google OAuth if it doesn't exist
    create_connected_account(user) if @provider == "google_oauth2"

    user
  end

  private

  # Finds a user by OAuth provider and UID
  #
  # @return [User, nil] The user if found
  def find_user_by_oauth
    User.find_by(oauth_provider: @provider, oauth_uid: @uid)
  end

  # Finds a user by email address
  #
  # @return [User, nil] The user if found
  def find_user_by_email
    User.find_by(email_address: @email)
  end

  # Creates a new user with OAuth data
  #
  # @return [User] The newly created user
  # @raise [ActiveRecord::RecordInvalid] If validation fails
  def create_user
    random_password = SecureRandom.hex(32)

    User.create!(
      email_address: @email,
      name: @name,
      password: random_password,
      password_confirmation: random_password,
      oauth_provider: @provider,
      oauth_uid: @uid,
      email_verified_at: Time.current # OAuth users are auto-verified
    )
  end

  # Updates OAuth fields for an existing user
  #
  # @param user [User] The user to update
  # @return [Boolean] True if update succeeds
  def update_oauth_fields(user)
    user.update(
      oauth_provider: @provider,
      oauth_uid: @uid,
      email_verified_at: Time.current # Mark as verified when linking OAuth
    )
  end

  # Creates a ConnectedAccount for the user if it doesn't exist
  #
  # @param user [User] The user to create the connected account for
  # @return [ConnectedAccount, nil] The created or existing connected account
  def create_connected_account(user)
    # Check if account already exists by provider and uid
    existing_account = user.connected_accounts.find_by(
      provider: @provider,
      uid: @uid
    )

    return existing_account if existing_account

    # Create new ConnectedAccount using the from_oauth method
    ConnectedAccount.from_oauth(user, @auth)
  end
end
