# frozen_string_literal: true

require "admin_suite/version"
require "admin_suite/configuration"
require "admin_suite/engine"

module AdminSuite
  class << self
    # @return [AdminSuite::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yieldparam config [AdminSuite::Configuration]
    # @return [AdminSuite::Configuration]
    def configure
      yield(config)
      config
    end
  end
end
