require "base64"
require "json"

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        # Prefer the explicit signed session cookie (if present).
        session_id = normalize_session_id(cookies.signed[:session_id])

        # Fall back to Rails cookie_store session (contains session[:auth_session_id]).
        if session_id.blank?
          session_id = extract_session_id_from_rails_session_cookie
        end

        return nil if session_id.blank?

        if (session = Session.find_by(id: session_id))
          self.current_user = session.user
        end
      end

      # When using :cookie_store, authenticated session id is stored inside the Rails session cookie
      # under :auth_session_id. ActionCable connections don't have access to controller `session`,
      # so we read/decrypt the session cookie directly.
      #
      # @return [String, nil]
      def extract_session_id_from_rails_session_cookie
        key = Rails.application.config.session_options[:key].to_s
        return nil if key.blank?

        # cookie_store uses encrypted cookies in modern Rails.
        raw_session = cookies.encrypted[key]
        raw_session = cookies.signed[key] if raw_session.nil?
        return nil if raw_session.blank?

        # Prefer Hash-shaped session payloads.
        if raw_session.is_a?(Hash)
          id = raw_session["auth_session_id"] || raw_session[:auth_session_id]
          return id.to_s if id.present?
        end

        nil
      rescue StandardError
        nil
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
  end
end
