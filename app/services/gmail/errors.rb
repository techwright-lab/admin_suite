# frozen_string_literal: true

# Gmail service exceptions
module Gmail
  module Errors
    class TokenExpiredError < StandardError; end
    class AuthorizationError < Google::Apis::AuthorizationError; end
    class RateLimitError < Google::Apis::RateLimitError; end
    class ServerError < Google::Apis::ServerError; end
    class ClientError < Google::Apis::ClientError; end
  end
end
