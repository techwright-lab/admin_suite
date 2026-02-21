# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.7] - 2026-02-21

### Changed

- Release notes are now auto-generated from commits since the previous tag when no `CHANGELOG.md` entry exists for the current version, instead of falling back to a plain "Release vX.Y.Z" string.

## [0.2.6] - 2026-02-21

### Added

- Automated GitHub Release creation in the publish workflow, with release notes extracted from `CHANGELOG.md`.

## [0.1.0] - 2026-02-04

### Added

- Initial extraction of the AdminSuite Rails engine.
- Resource/portal DSL, docs viewer, and theming primitives.
- Isolated gem test suite with a dummy Rails app.

