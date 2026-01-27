# Error Handling Audit

## Summary

Audit of all jobs and key services for proper error handling and ExceptionNotifier usage.

## Jobs Analysis

### ✅ Jobs with Proper Error Handling

| Job | Method |
|-----|--------|
| `GenerateRoundPrepJob` | Uses `handle_error` helper |
| `AssistantChatJob` | Uses `Ai::ErrorReporter.notify` |
| `AssistantToolFollowupJob` | Uses `Ai::ErrorReporter.notify` |
| `AssistantToolExecutionJob` | Uses `Ai::ErrorReporter.notify` |
| `CleanupStuckScrapingAttemptsJob` | Uses `ExceptionNotifier.notify` |

### ⚠️ Jobs with Partial Error Handling (Logging Only)

| Job | Issue |
|-----|-------|
| `ScrapeJobListingJob` | Has rescue blocks but only logs JSON, no notification |
| `RefreshOauthTokensJob` | Has rescue blocks but only logs |
| `GmailSyncAllUsersJob` | Has rescue block but only logs |
| `GmailSyncJob` | Auth failure handling good, but no general error notification |

### ❌ Jobs with No Error Handling

| Job | Risk |
|-----|------|
| `ProcessSignalExtractionJob` | Medium - Uses retry_on but no notification |
| `PurgeDeletedInterviewApplicationsJob` | Low - Simple cleanup |
| `GenerateInterviewPrepPackJob` | Medium - AI service calls |
| `Billing::ProcessWebhookEventJob` | High - Payment processing |
| `AssistantThreadSummarizerJob` | Low - Non-critical |
| `AssistantMemoryProposerJob` | Low - Non-critical |
| `RecomputeFitAssessmentsForUserJob` | Low - Batch job |
| `RecomputeFitAssessmentsForJobListingJob` | Low - Batch job |
| `ComputeFitAssessmentJob` | Low - Individual calculation |
| `AnalyzeResumeJob` | Medium - Relies on service |
| `ProcessOpportunityEmailJob` | Medium - AI extraction |

## Recommendations

### High Priority
1. Add error notification to `Billing::ProcessWebhookEventJob`
2. Add error notification to `GenerateInterviewPrepPackJob`
3. Add error notification to `ScrapeJobListingJob` (DLQ notifications)

### Medium Priority
4. Add error notification to `ProcessSignalExtractionJob`
5. Add error notification to `AnalyzeResumeJob`
6. Add error notification to `ProcessOpportunityEmailJob`

### Low Priority (Can rely on retry_on or are non-critical)
- Batch jobs (Recompute*, Purge*)
- Assistant memory/summarizer jobs
- OAuth refresh job (handled by account status)
