class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  layout "authentication"

  def new
    redirect_to root_path, alert: "Sign in is disabled." unless Setting.user_login_enabled?
  end

  def create
    unless Setting.username_password_login_enabled?
      redirect_to new_session_path, alert: "Username and password login is disabled."
      return
    end

    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.email_verified?
        start_new_session_for user
        redirect_to after_authentication_url
      else
        redirect_to new_session_path,
          alert: "Please verify your email first. Check your inbox for the verification link."
      end
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
