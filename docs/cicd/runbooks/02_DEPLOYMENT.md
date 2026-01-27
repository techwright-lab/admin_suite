# Deployment Runbook (Kamal)

## Scope

- Deployment tool: **Kamal** (`bin/kamal`)
- Deploy config: `config/deploy.yml`
- Artifact registry: `ghcr.io` (configured in `config/deploy.yml`)

## Prerequisites (must be true before deploying)

- You are an **authorized deployer** (SSH access to servers; registry access).
- CI is passing on the commit you intend to deploy.
- You have access to required secrets (see `config/deploy.yml` → `env.secret`).
- Your local git state is clean and updated:
  - `git status` has no unintended changes
  - deploy from `main` or an approved release tag

## Standard deployment (production)

1. Update local `main`:

```bash
git fetch --all --prune
git checkout main
git pull --ff-only
```

2. Confirm CI passed for the intended commit (GitHub Actions).
3. Ensure secrets are available for the deploy environment (do not print values).
4. Deploy:

```bash
bin/kamal deploy
```

5. Monitor rollout:

```bash
bin/kamal logs
```

6. Post-deploy verification checklist:
   - homepage loads
   - login works
   - background jobs are processing (Solid Queue)
   - billing/payment flows respond (if applicable)
   - error monitoring shows no spike (Sentry/Grafana/etc, as configured)

## Rollback

Use rollback when:
- elevated error rates
- critical user flows are broken
- a migration introduced incompatibility

```bash
bin/kamal rollback
bin/kamal logs
```

Then re-run the post-deploy verification checklist.

## Operational commands (defined aliases)

Aliases are defined in `config/deploy.yml`:

- Logs:

```bash
bin/kamal logs
```

- Rails console:

```bash
bin/kamal console
```

- Shell in container:

```bash
bin/kamal shell
```

## Database migrations during deploy

- Prefer backward-compatible migrations.
- When incompatible migrations are required:
  - coordinate the rollout plan in advance
  - have an explicit rollback plan
  - validate critical queries/flows post-deploy

