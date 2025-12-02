class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: :show
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  layout "authentication"

  # GET /email_verification/:token
  # Verify user's email address
  def show
    if @user.verify_email!
      # Send welcome email
      UserMailer.welcome(@user).deliver_later
      
      redirect_to new_session_path, notice: "Email verified! You can now sign in."
    else
      redirect_to new_session_path, alert: "Unable to verify email. Please try again."
    end
  end

  # POST /email_verification
  # Resend verification email
  def create
    if user = User.find_by(email_address: params[:email_address])
      unless user.email_verified?
        UserMailer.verify_email(user).deliver_later
      end
    end

    redirect_to new_session_path, notice: "Verification email sent (if user exists and is not verified)."
  end

  private
    def set_user_by_token
      @user = User.find_by_token_for(:email_verification, params[:token])
      
      unless @user
        redirect_to new_session_path, alert: "Email verification link is invalid or has expired."
      end
    end
end

