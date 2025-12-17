class ApplicationMailer < ActionMailer::Base
  default from: "Gleania <noreply@gleania.com>"
  layout "mailer"

  # Attach logo as inline attachment for all emails
  before_action :attach_logo

  private

  def attach_logo
    logo_path = Rails.root.join("app/assets/images/logo/logo.png")
    if File.exist?(logo_path)
      attachments.inline["logo.png"] = File.read(logo_path)
    end
  end
end
