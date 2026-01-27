# CI/CD Incident Response Runbook

## CI is red on `main`

1. **Pause deployments** until CI is green again.
2. Identify the failing workflow/job in GitHub Actions.
3. Decide: revert vs hotfix.
   - If revert is safe and fastest: open PR reverting the breaking commit.
   - Otherwise: open PR with a minimal hotfix.
4. Ensure CI passes on the PR.
5. Merge once green and reviewed.
6. Resume deployments.

## Bad deploy (production regression)

Trigger conditions:
- elevated error rates
- broken critical user flows
- infrastructure instability

Procedure:
1. Capture basic context:
   - deployed commit SHA
   - start time of incident
   - impacted endpoints/features
2. Roll back:

```bash
bin/kamal rollback
bin/kamal logs
```

3. Verify recovery:
   - homepage loads
   - login works
   - key flows work
4. Create an incident ticket with timestamps, commit SHA(s), and the rollback action taken.

## Evidence collection (for audits/assessments)

- Link to the GitHub Actions run(s) involved.
- Note deployed commit SHA and rollout time.
- Attach relevant log excerpts (do not include secrets).

