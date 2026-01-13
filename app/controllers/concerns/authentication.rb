module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session # Always resume session to make authenticated? work in views
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      set_no_cache_headers
      resume_session || request_authentication
    end

    def set_no_cache_headers
      response.set_header("Cache-Control", "no-store, private")
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      # Prefer Rails session storage (works even when ActionDispatch::Cookies isn't fully available)
      if respond_to?(:session) && session.respond_to?(:[])
        session_id = session[:auth_session_id]
        return Session.find_by(id: session_id) if session_id.present?
      end

      # Fallback to signed cookie storage when available
      return nil unless respond_to?(:cookies) && cookies&.respond_to?(:signed)

      raw = cookies.signed[:session_id]
      session_id = normalize_session_id(raw)
      return nil if session_id.blank?

      Session.find_by(id: session_id)
    end

    # Normalizes the signed cookie payload to a usable session id.
    #
    # Rails cookie jars may return:
    # - a String/Integer session id
    # - a metadata Hash (depending on cookie serializer/version)
    #
    # @param raw [Object]
    # @return [String, nil]
    def normalize_session_id(raw)
      return nil if raw.blank?

      if raw.is_a?(Hash)
        payload = raw["_rails"] || raw[:_rails]
        message = payload.is_a?(Hash) ? (payload["message"] || payload[:message]) : nil
        raw = message if message.present?
      end

      value = raw.to_s
      return value if value.match?(/\A\d+\z/)

      # Some Rails cookie formats base64-encode the message.
      if value.match?(/\A[A-Za-z0-9+\/]+=*\z/)
        decoded = Base64.decode64(value).to_s
        return decoded if decoded.match?(/\A\d+\z/)

        # Some formats wrap the signed value as JSON metadata:
        # {"_rails":{"message":"<base64>","exp":...,"pur":...}}
        if decoded.strip.start_with?("{")
          begin
            data = JSON.parse(decoded)
            payload = data["_rails"] || data.dig("_rails")
            message = payload.is_a?(Hash) ? payload["message"] : nil
            if message.is_a?(String)
              inner = Base64.decode64(message).to_s
              return inner if inner.match?(/\A\d+\z/)
            end
          rescue JSON::ParserError
            # ignore
          end
        end
      end

      nil
    rescue ArgumentError
      nil
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || dashboard_path
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |user_session|
        Current.session = user_session
        # Store session id in Rails session for reliability.
        session[:auth_session_id] = user_session.id if respond_to?(:session) && session.respond_to?(:[]=)

        # Also store in a signed cookie when available (helps if session store changes later).
        if respond_to?(:cookies) && cookies&.respond_to?(:permanent) && cookies.permanent.respond_to?(:signed)
          cookies.permanent.signed[:session_id] = user_session.id
        end
      end
    end

    def terminate_session
      Current.session.destroy
      session.delete(:auth_session_id) if respond_to?(:session) && session.respond_to?(:delete)
      cookies.delete(:session_id) if respond_to?(:cookies) && cookies.respond_to?(:delete)
    end
end
