# Releasing

This page is intended for maintainers publishing `admin_suite` to RubyGems.

## Checklist

1. Bump the version

- Update `lib/admin_suite/version.rb`

2. Update changelog

- Add an entry to `CHANGELOG.md`

3. Run tests and build the gem

```bash
bundle exec rake test
gem build admin_suite.gemspec
```

4. (Recommended) Tag the release

```bash
git tag -a "vX.Y.Z" -m "AdminSuite vX.Y.Z"
git push --tags
```

5. Publish to RubyGems

```bash
gem push "admin_suite-X.Y.Z.gem"
```

Notes:

- RubyGems commonly requires MFA/OTP for pushes (this gem is configured with `rubygems_mfa_required`).

