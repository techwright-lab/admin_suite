class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }
  layout "authentication"

  # GET /registrations/new
  # Show registration form
  def new
    @user = User.new
  end

  # POST /registrations
  # Create new user account
  def create
    # Verify Turnstile token
    unless verify_turnstile_token
      @user = User.new(registration_params)
      @user.errors.add(:base, "Verification failed. Please try again.")
      render :new, status: :unprocessable_entity
      return
    end

    @user = User.new(registration_params)

    if @user.save
      # Send verification email
      UserMailer.verify_email(@user).deliver_later

      redirect_to new_session_path, notice: "Account created! Please check your email to verify your account."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(user: [ :email_address, :password, :password_confirmation, :name ])
    end

    # Verifies Turnstile token if configured
    #
    # @return [Boolean]
    def verify_turnstile_token
      return true unless turnstile_configured?

      token = params[:cf_turnstile_response]
      CloudflareTurnstileService.verify(token, request.remote_ip)
    end
end
