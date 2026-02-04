# AdminSuite

A mountable Rails engine that provides a resource-based admin UI and generators.

This engine is currently extracted from TechWright Labs's products and is intended to be reused
across other products.

## Development

Install dependencies:

```bash
bundle install
```

Run the test suite:

```bash
bundle exec rake test
```

Build the gem:

```bash
gem build admin_suite.gemspec
```

## Release

- Bump the version in `lib/admin_suite/version.rb`
- Update `CHANGELOG.md`
- Run tests and build:

```bash
bundle exec rake test
gem build admin_suite.gemspec
```

- (Recommended) Tag the release:

```bash
git tag -a "vX.Y.Z" -m "AdminSuite vX.Y.Z"
git push --tags
```

- Push to RubyGems (you’ll be prompted for MFA/OTP if enabled):

```bash
gem push "admin_suite-X.Y.Z.gem"
```

