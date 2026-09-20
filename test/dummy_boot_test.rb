# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class DummyBootTest < ActiveSupport::TestCase
  test "database-free dummy boots and eager loads in development" do
    script = <<~RUBY
      require_relative "test/dummy/config/environment"
      abort "Unexpected ActiveRecord railtie" if Rails.application.config.respond_to?(:active_record)
      Rails.application.eager_load!
    RUBY
    stdout, stderr, status = Open3.capture3(
      { "RAILS_ENV" => "development" }, RbConfig.ruby, "-e", script,
      chdir: File.expand_path("..", __dir__)
    )

    assert status.success?, "Development boot failed:\n#{stdout}#{stderr}"
  end
end
