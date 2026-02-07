source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"

gem "dotenv-rails", require: "dotenv/load"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Rails 8.1.1's test runner integration is not compatible with Minitest 6 yet.
# Pin to Minitest 5.x so tests are discoverable and runnable.
gem "minitest", "< 6"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.21"

# State machine management
gem "aasm"
gem "after_commit_everywhere", "~> 1.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "mission_control-jobs"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # FactoryBot for test data
  gem "factory_bot_rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"

  # Code coverage reporting (opt-in via COVERAGE=1)
  gem "simplecov", require: false

  # HTTP request stubbing and recording
  gem "vcr"
  gem "webmock"

  # Database cleaning between tests
  gem "database_cleaner-active_record"
end

gem "stackprof"
gem "sentry-ruby"
gem "sentry-rails"

# Analytics
gem "mixpanel-ruby"
gem "groupdate"
gem "chartkick"

# Microscope adds useful scopes targeting ActiveRecord `boolean`, `date` and `datetime` attributes.
# https://github.com/mirego/microscope
gem "microscope"

# The bullet_train-action_models gem can use OpenAI during the CSV import process to
# automatically match column names to database attributes.
# https://github.com/alexrudall/ruby-openai
gem "ruby-openai"

# Anthropic Claude API client
gem "anthropic"

# HTTP client for making requests
gem "httparty"

# OAuth for third-party integrations (Gmail, etc.)
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# Google API clients for Gmail and Calendar
gem "google-apis-gmail_v1"
gem "google-apis-calendar_v3"

# Two-factor authentication
gem "rotp"
gem "rqrcode"

# Robots.txt parser for respectful scraping
gem "robots"

# HTML parsing and cleaning
gem "nokogiri"

# JS-rendered scraping (headless browser)
gem "selenium-webdriver"

# Document parsing for resume extraction
gem "pdf-reader"      # PDF text extraction
gem "docx"            # DOCX text extraction

# awesome_print allows us to `ap` our objects for a clean presentation of them.
# https://github.com/awesome-print/awesome_print
gem "awesome_print"

group :production, :staging do
  # We suggest using Postmark for email deliverability.
  gem "postmark-rails"
  gem "logtail-rails"

  # Use S3 for Active Storage by default.
  gem "aws-sdk-s3", require: false

  # terser is used to compress assets during precompilation
  gem "terser"
end

# Protect the API routes via CORS
gem "rack-cors"
gem "rack-cache"

# Easy and automatic inline CSS for mailers
gem "premailer-rails"

group :development do
  # Open any sent emails in your browser instead of having to setup an SMTP trap.
  gem "letter_opener"
  gem "letter_opener_web", "~> 3.0"

  # Ruby formatter. Try `standardrb --fix`.
  gem "standard"

  # Similar to standard for correcting format.
  gem "rails_best_practices"

  # Rails doesn't include this by default, but we depend on it.
  gem "foreman"

  # For colorizing text in command line scripts.
  gem "colorize"

  # derailed_benchmarks and stackprof are used to find opportunities for performance/memory improvements
  # See the derailed_benchmarks docs for details: https://github.com/zombocom/derailed_benchmarks
  gem "derailed_benchmarks"
end

gem "friendly_id"

# Pagination
gem "pagy", "~> 9.0"

# Internal admin suite engine (local path during extraction)
gem "admin_suite", "~> 0.2.1"

# Blog: tags, markdown, SEO meta, newsletter
gem "acts-as-taggable-on"
gem "commonmarker"
gem "meta-tags"
gem "mailkick"

gem "rouge", "~> 4.7"

gem "redcarpet", "~> 3.6"

# Runtime contracts / schema validation (use at boundaries like LLM tool calls/results)
gem "dry-schema"
gem "json_schemer"

group :production do
  # OpenTelemetry for observability
  gem "opentelemetry-sdk"
  gem "opentelemetry-logs-sdk"
  gem "opentelemetry-exporter-otlp"
  gem "opentelemetry-instrumentation-rails"
  gem "opentelemetry-instrumentation-logger"
  gem "opentelemetry-instrumentation-net_http"
  gem "opentelemetry-instrumentation-pg"
  gem "opentelemetry-exporter-otlp-logs", "~> 0.2.2"
end
