# Email-Driven Interview Application Automation

## Overview

Automatically process interview-related emails to update application status, create interview rounds, capture feedback, and track the entire hiring pipeline without manual intervention.

## Implementation Status

### Completed Features

- ✅ Email sync from Gmail via `Gmail::SyncService`
- ✅ Email classification via `Gmail::EmailProcessorService` (includes new `round_feedback` type)
- ✅ Signal extraction via `Signals::ExtractionService` (company, recruiter, job info, action links)
- ✅ Manual email-to-application matching
- ✅ **Automatic interview round creation** from scheduling/interview emails (`Signals::InterviewRoundProcessor`)
- ✅ **Automatic round feedback processing** (`Signals::RoundFeedbackProcessor`)
- ✅ **Automatic application status updates** from rejection/offer emails (`Signals::ApplicationStatusProcessor`)
- ✅ **Automatic company feedback capture** (`Signals::CompanyFeedbackProcessor`)
- ✅ Integrated processing pipeline via `ProcessSignalExtractionJob`

---

## Architecture

### Email Processing Pipeline

```
Email Synced (Gmail::SyncService)
    │
    ▼
Email Classified (Gmail::EmailProcessorService)
    │
    ▼
Application Matching
    │
    ▼
Signal Extraction (Signals::ExtractionService) ─── Company, Recruiter, Job info
    │
    ▼
ProcessSignalExtractionJob
    │
    ├─► scheduling/interview_invite/interview_reminder
    │       └─► InterviewRoundProcessor ──► Create/Update InterviewRound
    │
    ├─► round_feedback
    │       └─► RoundFeedbackProcessor ──► Update Round Result + InterviewFeedback
    │
    ├─► rejection/offer
    │       └─► ApplicationStatusProcessor ──► Update Application Status + CompanyFeedback
    │
    └─► All matched emails
            └─► CompanyFeedbackProcessor ──► Capture any feedback
```

---

## Components

### 1. Interview Round Processing (`Signals::InterviewRoundProcessor`)

**Handles**: `scheduling`, `interview_invite`, `interview_reminder` emails

**Extracts via `Ai::InterviewExtractionPrompt`**:
- `scheduled_at` - DateTime with timezone
- `duration_minutes` - 30, 45, 60, etc.
- `stage` - screening, technical, hiring_manager, culture_fit, other
- `interviewer_name` and `interviewer_role`
- `video_link` - Zoom/Meet/Teams URL
- `confirmation_source` - calendly, goodtime, greenhouse, lever, manual

**Creates**: `InterviewRound` with full details linked to source email

---

### 2. Round Feedback Processing (`Signals::RoundFeedbackProcessor`)

**Handles**: `round_feedback` emails (passed/failed a round)

**Extracts via `Ai::RoundFeedbackExtractionPrompt`**:
- `result` - passed, failed, waitlisted
- `feedback_text` - Detailed feedback if provided
- `strengths` and `improvements`
- `next_round_hint` - Information about upcoming rounds

**Updates**: 
- `InterviewRound.result` (passed/failed/waitlisted)
- Creates `InterviewFeedback` record with extracted details

---

### 3. Application Status Processing (`Signals::ApplicationStatusProcessor`)

**Handles**: `rejection`, `offer` emails

**Extracts via `Ai::StatusExtractionPrompt`**:
- `status_type` - rejection, offer, withdrawal, on_hold
- `rejection_reason` - Position filled, other candidates, etc.
- `offer_details` - Role, start date, deadline
- `feedback_text` - Any overall feedback

**Updates**:
- `InterviewApplication.status` (rejected, accepted)
- `InterviewApplication.pipeline_stage` (offer, closed)
- Creates `CompanyFeedback` record

---

### 4. Company Feedback Processing (`Signals::CompanyFeedbackProcessor`)

**Handles**: All matched emails with extractable feedback

**Creates**: `CompanyFeedback` records from any email containing feedback

---

## Database Schema Additions

### `interview_rounds`
```ruby
add_column :interview_rounds, :source_email_id, :bigint
add_column :interview_rounds, :video_link, :string
add_column :interview_rounds, :confirmation_source, :string
add_index :interview_rounds, :source_email_id
```

### `company_feedbacks`
```ruby
add_column :company_feedbacks, :source_email_id, :bigint
add_column :company_feedbacks, :feedback_type, :string
add_index :company_feedbacks, :source_email_id
```

---

## Email Type Patterns

### `round_feedback` (New)
```ruby
round_feedback: [
  /you('ve| have)?\s+(passed|cleared|moved forward)/i,
  /pleased\s+to\s+inform\s+you/i,
  /congratulations.*next\s+(round|stage)/i,
  /moving\s+(you\s+)?(forward|ahead)/i,
  /advancing\s+to\s+(the\s+)?next/i,
  /proceed(ing)?\s+to\s+(the\s+)?(next|final)/i,
  /unfortunately.*not\s+(moving|proceeding)/i,
  /feedback\s+(from|on)\s+your\s+(interview|round)/i,
  /interview\s+feedback/i,
  /results?\s+(of|from)\s+(your\s+)?interview/i,
  /waitlist(ed)?/i
]
```

---

## File Structure

```
app/models/ai/
├── interview_extraction_prompt.rb      # LLM prompt for interview details
├── round_feedback_extraction_prompt.rb # LLM prompt for round feedback
└── status_extraction_prompt.rb         # LLM prompt for rejection/offer

app/services/signals/
├── interview_round_processor.rb        # Creates rounds from scheduling emails
├── round_feedback_processor.rb         # Updates round results from feedback
├── application_status_processor.rb     # Updates status from rejection/offer
└── company_feedback_processor.rb       # Captures feedback from any email

app/jobs/
└── process_signal_extraction_job.rb    # Orchestrates all processors
```

---

## Example Scenarios

### Scenario 1: GoodTime Confirmation
```
Subject: Interview Confirmed - Software Engineer at Toptal
From: scheduling@goodtime.io

Your interview has been scheduled!

Role: Software Engineer
Date: Tuesday, January 21, 2026
Time: 2:00 PM - 2:30 PM PST
Duration: 30 minutes

Interviewer: Silvana Palacios, Senior Recruiter
Join via Zoom: https://zoom.us/j/123456789
```

**Automated Action**:
- `InterviewRoundProcessor` creates `InterviewRound`:
  - `scheduled_at: 2026-01-21 14:00:00 PST`
  - `duration_minutes: 30`
  - `stage: :screening`
  - `interviewer_name: "Silvana Palacios"`
  - `video_link: "https://zoom.us/j/123456789"`
  - `confirmation_source: "goodtime"`

---

### Scenario 2: Round Passed Email
```
Subject: Great news - Moving to next round!
From: recruiting@acme.com

Hi Ravi,

Congratulations! You've passed the technical interview.
The team was impressed with your system design skills.

Next up is a 30-minute call with the hiring manager.
```

**Automated Action**:
- `RoundFeedbackProcessor` updates `InterviewRound`:
  - `result: :passed`
- Creates `InterviewFeedback`:
  - `went_well: "System design skills"`
  - `recommended_action: "Prepare for hiring manager round"`

---

### Scenario 3: Rejection Email
```
Subject: Update on your application - Acme Corp
From: recruiting@acme.com

Thank you for interviewing with us. After careful consideration,
we've decided to move forward with other candidates.
```

**Automated Action**:
- `ApplicationStatusProcessor` updates `InterviewApplication`:
  - `status: :rejected`
  - `pipeline_stage: :closed`
- Creates `CompanyFeedback`:
  - `feedback_type: "rejection"`
  - `rejection_reason: "Moving forward with other candidates"`

---

### Scenario 4: Offer Email
```
Subject: Offer Letter - Senior Engineer at Startup Inc
From: hr@startup.com

Congratulations! We are pleased to extend an offer for Senior Engineer.
Please review and respond by January 25th.
```

**Automated Action**:
- `ApplicationStatusProcessor` updates `InterviewApplication`:
  - `pipeline_stage: :offer`
- Creates `CompanyFeedback`:
  - `feedback_type: "offer"`
  - `next_steps: "Respond by: January 25th"`

---

## Future Enhancements

### Sprint 4: Polish & Edge Cases
- [ ] Handle rescheduling emails (update existing round)
- [ ] Handle cancellation emails
- [ ] Add user notifications for auto-actions
- [ ] Add override UI for corrections
- [ ] Improve round matching accuracy

### Future: Calendar Integration
- [ ] Read Google Calendar events to detect interviews
- [ ] Create calendar events from interview invites
- [ ] Update rounds when calendar events change
- [ ] Send reminders before interviews

---

## Success Metrics

1. **Automation Rate**: % of interview rounds auto-created vs manual
2. **Accuracy**: % of correct status updates and round results
3. **Time Saved**: Reduction in manual data entry
4. **User Corrections**: How often users need to fix auto-created data
