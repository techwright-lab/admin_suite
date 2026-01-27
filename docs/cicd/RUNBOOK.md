# CI/CD Runbooks (Index)

This file is the **entry point** for CI/CD documentation and CASA Tier 2 evidence. Each responsibility has its own focused runbook.

## Runbooks

- **Overview**: [`runbooks/00_OVERVIEW.md`](runbooks/00_OVERVIEW.md)
- **CI (GitHub Actions)**: [`runbooks/01_CI.md`](runbooks/01_CI.md)
- **Deployments (Kamal)**: [`runbooks/02_DEPLOYMENT.md`](runbooks/02_DEPLOYMENT.md)
- **Secrets (Rails encrypted credentials)**: [`runbooks/03_SECRETS_AND_CREDENTIALS.md`](runbooks/03_SECRETS_AND_CREDENTIALS.md)
- **Incident response**: [`runbooks/04_INCIDENT_RESPONSE.md`](runbooks/04_INCIDENT_RESPONSE.md)

## CASA evidence pointers

- CI workflow: `.github/workflows/ci.yml`
- Deployment automation/config-as-code: `config/deploy.yml`
- Kamal deployment automation: `bin/kamal` and `.kamal/hooks/*` templates
- Secrets injection list: `config/deploy.yml` → `env.secret` (includes `RAILS_MASTER_KEY`)

