# Contributing to AdminSuite

Thank you for your interest in contributing to AdminSuite!

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Install dependencies: `bundle install`
4. Run the test suite: `bundle exec rake test`
5. (Optional) Run tests with coverage: `COVERAGE=true bundle exec rake test`

## Development

See `docs/development.md` for detailed information on:
- Setting up your development environment
- Running tests
- Code style guidelines

## Pull Requests

1. Create a feature branch from `main`
2. Make your changes
3. Add or update tests as needed
4. Ensure all tests pass: `bundle exec rake test`
5. Push your branch and create a pull request

### CI Checks

All pull requests must pass the following checks before merging:
- **Tests**: Automated test suite runs on Ruby 3.2 and 3.3
- **Coverage**: Code coverage is automatically generated and uploaded to Codecov
- **Code Review**: At least one maintainer approval required

The CI workflow runs automatically on every pull request.

## Releasing

See `docs/releasing.md` for information on how releases are managed.

Releases are automated via GitHub Actions when changes are merged to `main` with a version bump.

### Required Secrets for Maintainers

The repository requires the following secrets to be configured:
- **`RUBYGEMS_API_KEY`**: Required for automated gem publishing to RubyGems
- **`CODECOV_TOKEN`**: Optional, for uploading code coverage reports to Codecov (workflow continues without it)

## Questions?

Feel free to open an issue for questions or discussion.
