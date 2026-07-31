# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-07-31

### Changed (BREAKING)
- AdminSuite now **fails closed**: with no authentication configured, every
  engine request responds 403. Configure `config.auth_strategy = :http_basic`
  (or a custom strategy, or the legacy `config.authenticate` lambda). For
  development/test only, `config.allow_unauthenticated = true` restores open
  access (ignored in production).
- `read_only` resources now also reject the built-in `toggle` endpoint;
  undeclared `execute_action` and `bulk_action` names respond 404 via a
  dedicated bulk-action lookup. Declared member and bulk actions remain
  allowed on `read_only` resources by design.
- `execute_action` with an unknown action name now responds 404 instead of
  redirecting with an "Action not found." alert.

### Added
- Pluggable auth strategies: `AdminSuite::Auth.register`, built-in
  `:http_basic` (ENV or `config.auth_options` credentials, constant-time
  comparison, blank credentials deny).
- `config.authorize` is now enforced for every resource action with the
  contract `->(actor:, action:, resource:, record:, controller:)`,
  action ∈ :read/:create/:update/:destroy/:execute.
- `config.skip_host_before_actions` (default `[:require_authentication]`)
  replaces the hardcoded host-filter skip.

### Fixed
- `config.current_actor` is now consulted at most once per request
  (was invoked repeatedly by views; side-effecting lambdas fired multiple times).

## [0.2.9] - 2026-07-14

### Added

- Read-only resource support, server-side filter defaults, and filtered-scope statistics.

## [0.2.8] - 2026-03-23

### Added

- **Dependent searchable select** field type (`:dependent_select`) — cascading dropdowns where a child field's options filter by the selected parent value. Uses `parent_field:` option and `[label, value, group]` collection triples.
- **Stimulus entry point** (`admin_suite_application.js`) — automatically imports and registers all 12 AdminSuite Stimulus controllers on `window.Stimulus`.
- `parent_field` attribute on `FieldDefinition` for linking dependent fields.

### Fixed

- **Stimulus controllers not loading** — engine controllers were pinned via importmap but never imported. Added explicit entry point in layout via `<script type="module">`.
- **Searchable select change propagation** — `applyOption()` now dispatches a `change` event on the hidden input, enabling dependent field chaining.

### Security

- New `dependent_searchable_select_controller.js` uses safe DOM construction (`createElement`/`textContent`/`appendChild`) instead of `innerHTML` template literals.

## [0.2.6] - 2026-02-21

### Added

- Automated GitHub Release creation in the publish workflow, with release notes extracted from `CHANGELOG.md`.
- When no `CHANGELOG.md` entry exists for the current version, release notes are now primarily auto-generated from commits since the previous tag, with the plain "Release vX.Y.Z" string used only as a final fallback when no commit-generated notes are available.

## [0.1.0] - 2026-02-04

### Added

- Initial extraction of the AdminSuite Rails engine.
- Resource/portal DSL, docs viewer, and theming primitives.
- Isolated gem test suite with a dummy Rails app.
