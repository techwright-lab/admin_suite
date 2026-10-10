# AdminSuite agent instructions

Start with `README.md` for the repository entry point.

Architecture boundaries are `bin/archspec check` and `bin/archspec-baseline` (`Archspec.rb`). Do not grow `archspec_todo.yml`. The hosted `architecture` job runs both commands. Checks do not boot Rails.

## Agent skills

### Issue tracker

Track work in Paperclip (TechWright Labs, TEC), not GitHub Issues.
Before tracker operations, read `../_vault/products/admin_suite/docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels.
Before triage, read `../_vault/products/admin_suite/docs/agents/triage-labels.md`.

### Domain docs

Single-context glossary and ADRs live in the vault.
Before exploring code, read `../_vault/products/admin_suite/docs/agents/domain.md`.

## Product documentation (normative)

- Canonical AdminSuite docs live in `../_vault/products/admin_suite/docs/` in the TechWright workspace.
- Read `../_vault/organization/policies/product-documentation-placement.md` before creating or relocating product documentation.
- Do not create a repo `docs/` tree or a docs symlink. Write plans, designs, specs, decisions, runbooks, reports, audits, and research directly to the vault and link them from issues/PRs.
- Host applications may configure the AdminSuite docs viewer with `config.docs_path`; do not interpret that generic feature as permission to restore TechWright product docs inside a product repo.
