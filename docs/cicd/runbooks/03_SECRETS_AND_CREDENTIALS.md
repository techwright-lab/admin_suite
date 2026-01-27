# Secrets Runbook (Rails Encrypted Credentials + Deploy-time Injection)

## Purpose

Document how Gleania manages secrets securely and repeatably for CI/CD and production deployments.

## Source of truth: Rails encrypted credentials

Gleania uses **Rails encrypted credentials** as the primary secrets store for application configuration (API keys, OAuth secrets, etc.).

- Encrypted files:
  - `config/credentials.yml.enc` (and/or environment-specific encrypted files if used)
- Decryption key:
  - `RAILS_MASTER_KEY`
  - `config/master.key` may be used locally, but must never be committed

## Editing credentials (authorized engineers only)

1. Ensure you have the correct `RAILS_MASTER_KEY` for the target environment.
2. Edit:

```bash
bin/rails credentials:edit --environment production
```

3. Commit only encrypted file changes (`*.yml.enc`). Never commit plaintext secrets.

## How secrets reach production (repeatable + non-interactive)

Production deploys are repeatable because the app decrypts credentials at boot using `RAILS_MASTER_KEY`.

- `config/deploy.yml` lists required env vars under `env.secret` (includes `RAILS_MASTER_KEY`)
- The deploy environment provides these values at runtime via Kamal secrets (`.kamal/secrets`)
- `.kamal/secrets` must not be committed and should only exist on authorized deploy machines

## Rotation

When rotating secrets:

- Update encrypted credentials.
- If rotating `RAILS_MASTER_KEY`, coordinate key distribution to deployers/automation.
- Redeploy.
- Verify application health post-deploy.

## Access control & leak prevention

- Restrict who can access the master key and who can run `credentials:edit`.
- Store master keys in approved access-controlled storage per internal policy.
- Never print secrets in logs/CI output.
- Never paste secrets into tickets/PRs/chat.
- CI should not require production secrets; tests should use safe defaults/stubs.

