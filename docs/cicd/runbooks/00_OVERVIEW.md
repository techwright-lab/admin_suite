# CI/CD Runbooks — Overview (CASA Tier 2 Evidence)

## Purpose

This directory contains **role-focused** runbooks for Gleania’s secure and repeatable CI/CD and deployment processes.

## What’s here

- **CI**: `01_CI.md` — how CI runs, what it checks, and how to respond to failures
- **Deployments**: `02_DEPLOYMENT.md` — how to deploy/rollback with Kamal safely
- **Secrets**: `03_SECRETS_AND_CREDENTIALS.md` — Rails encrypted credentials and how `RAILS_MASTER_KEY` is provisioned
- **Incident response**: `04_INCIDENT_RESPONSE.md` — CI red, bad deploy, rollback, evidence collection

## Evidence pointers (files)

- CI workflow: `.github/workflows/ci.yml`
- Deployment automation/config-as-code: `config/deploy.yml`
- Kamal automation entrypoint: `bin/kamal` (plus `.kamal/hooks/*` templates)
- Secrets list injected at deploy: `config/deploy.yml` → `env.secret`

