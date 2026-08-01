source "https://rubygems.org"

# Declare runtime dependencies in the gemspec.
gemspec

group :development, :test do
  # Provides the asset pipeline used by the engine/dummy app.
  gem "propshaft"
end

group :test do
  gem "simplecov", require: false
  # minitest 6.x split Object#stub out of core; needed for Rails.stub in
  # test/integration/authentication_test.rb.
  gem "minitest-mock"
end
