module SessionTestHelper
  def sign_in_as(user)
    if is_a?(ActionDispatch::IntegrationTest)
      # For integration tests, use the actual login flow
      user.update!(email_verified_at: Time.current) unless user.email_verified?
      post session_path, params: { email_address: user.email_address, password: "password" }
      # Follow redirect once to ensure session is established
      follow_redirect! if response.redirect?
    else
      # For model tests, create session directly
      user.update!(email_verified_at: Time.current) unless user.email_verified?
      user_session = user.sessions.create!(
        user_agent: "Test Browser",
        ip_address: "127.0.0.1"
      )
      Current.session = user_session
    end
  end

  def sign_out
    Current.session&.destroy
    if is_a?(ActionDispatch::IntegrationTest)
      if respond_to?(:session)
        rails_session = session
        if rails_session && rails_session.respond_to?(:delete)
          rails_session.delete(:auth_session_id)
        end
      end
      if respond_to?(:cookies) && cookies.respond_to?(:delete)
        cookies.delete(:session_id)
      end
    end
    Current.reset
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
