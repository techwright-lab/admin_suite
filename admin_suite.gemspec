# frozen_string_literal: true

require_relative "lib/admin_suite/version"

Gem::Specification.new do |spec|
  spec.name = "admin_suite"
  spec.version = AdminSuite::VERSION
  spec.authors = [ "TechWright Labs" ]
  spec.email = [ "engineering@techwright.io" ]

  spec.summary = "Reusable admin suite engine"
  spec.description = "A Rails engine providing a declarative resource DSL and a Hotwire/Tailwind admin UI."
  # TODO: set to the new GitHub repo URL before publishing.
  spec.homepage = "https://github.com/techwright-lab/admin_suite"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["rubygems_mfa_required"] = "true"
  # Optional, but recommended once the repo exists:
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "app/**/*",
      "docs/**/*",
      "lib/**/*",
      "test/**/*",
      "config/**/*",
      "CHANGELOG.md",
      "Gemfile",
      "Rakefile",
      ".gitignore",
      "README.md",
      "CONTRIBUTING.md",
      "LICENSE.txt"
    ]
  end

  spec.add_dependency "rails", ">= 8.0", "< 9.0"
  spec.add_dependency "pagy", ">= 6.0", "< 11.0"
  spec.add_dependency "lucide-rails", "~> 0.7"
  spec.add_dependency "redcarpet", "~> 3.6"
  spec.add_dependency "rouge", "~> 4.7"
  # Provides the `tailwindcss` executable so the engine can build its own CSS
  # during asset precompile (no host Tailwind setup required).
  spec.add_dependency "tailwindcss-ruby", "~> 4.1"
end
