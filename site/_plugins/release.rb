# frozen_string_literal: true

require_relative "../../lib/admin_suite/version"

Jekyll::Hooks.register :site, :post_read do |site|
  site.data["release"] = { "version" => AdminSuite::VERSION }
end
