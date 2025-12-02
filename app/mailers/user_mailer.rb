class UserMailer < ApplicationMailer
  # Sends email verification link to user
  # @param user [User] The user to send verification to
  def verify_email(user)
    @user = user
    @verification_url = email_verification_url(@user.generate_token_for(:email_verification))
    
    mail(
      to: user.email_address,
      subject: "Verify your Gleania account"
    )
  end

  # Sends welcome email after user verifies their email
  # @param user [User] The newly verified user
  def welcome(user)
    @user = user
    
    mail(
      to: user.email_address,
      subject: "Welcome to Gleania! 🎉"
    )
  end
end

