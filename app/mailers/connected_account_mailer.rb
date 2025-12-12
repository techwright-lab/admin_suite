# frozen_string_literal: true

# Mailer for connected account notifications
class ConnectedAccountMailer < ApplicationMailer
  # Sends a notification when a connected account needs reauthorization
  #
  # @param connected_account [ConnectedAccount] The account that needs reauth
  def reauth_required(connected_account)
    @account = connected_account
    @user = connected_account.user

    mail(
      to: @user.email_address,
      subject: "Action Required: Reconnect your Gmail account"
    )
  end
end
