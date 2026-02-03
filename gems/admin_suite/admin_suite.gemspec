# frozen_string_literal: true

require_relative "lib/admin_suite/version"

Gem::Specification.new do |spec|
  spec.name = "admin_suite"
  spec.version = AdminSuite::VERSION
  spec.authors = [ "TechWright Labs" ]
  spec.email = [ "engineering@techwright.io" ]

  spec.summary = "Reusable admin suite engine for Gleania products."
  spec.description = "A Rails engine providing a declarative resource DSL and a Hotwire/Tailwind admin UI."
  spec.homepage = "https://example.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "app/**/*",
      "lib/**/*",
      "README.md",
      "LICENSE.txt"
    ]
  end

  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "pagy", ">= 6.0"
end
