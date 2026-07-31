# frozen_string_literal: true

# The dummy app's pre-auth integration tests exercise pages without
# authentication. Fail-closed is covered explicitly in
# test/integration/authentication_test.rb by flipping this off.
AdminSuite.configure do |config|
  config.allow_unauthenticated = true
end
