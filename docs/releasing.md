# Releasing

This page is intended for maintainers publishing `admin_suite` to RubyGems.

## Automated Release Process (Recommended)

The gem is automatically published to RubyGems when changes are merged to `main`, provided the version has been bumped.

### Steps

1. **Bump the version**
   - Update `lib/admin_suite/version.rb`

2. **Update changelog**
   - Add an entry to `CHANGELOG.md`

3. **Create a PR and get it merged**
   - The CI workflow will run tests automatically on the PR
   - Once merged to `main`, after CI passes, the publish workflow will:
     - Check if the version already exists on RubyGems
     - Build and publish the gem (if it's a new version)
     - Create a Git tag for the release (if it doesn't already exist)
     - Create a GitHub Release with notes extracted from `CHANGELOG.md`

### Requirements

- The `RUBYGEMS_API_KEY` secret must be configured in the repository settings
- The version in `lib/admin_suite/version.rb` must be unique (not already published)

## Manual Release Process

If you need to publish manually:

1. Bump the version
   - Update `lib/admin_suite/version.rb`

2. Update changelog
   - Add an entry to `CHANGELOG.md`

3. Run tests and build the gem

```bash
bundle exec rake test
gem build admin_suite.gemspec
```

4. Tag the release

```bash
git tag -a "vX.Y.Z" -m "AdminSuite vX.Y.Z"
git push --tags
```

5. Publish to RubyGems

```bash
gem push "admin_suite-X.Y.Z.gem"
```

## Notes

- RubyGems commonly requires MFA/OTP for pushes (this gem is configured with `rubygems_mfa_required`)
- The automated workflow uses a GitHub Actions bot to push tags and create GitHub Releases
- The publish workflow only runs after the CI workflow completes successfully
- GitHub Release notes are automatically extracted from the matching version section in `CHANGELOG.md`
- You can manually trigger the publish workflow from the GitHub Actions tab if needed

