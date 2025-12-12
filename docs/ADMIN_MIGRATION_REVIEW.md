# Admin System Migration - Additional Resources Review

## Summary

After reviewing the codebase, here are additional models/resources that could benefit from admin management interfaces.

## Already Migrated ✅

1. **Company** - Full CRUD
2. **JobRole** - Full CRUD
3. **Setting** - Full CRUD (with new functionality)
4. **ExtractionPromptTemplate** - Full CRUD + activate/duplicate actions
5. **LlmProviderConfig** - Full CRUD + test_provider action

## Recommended for Migration

### High Priority

#### 1. **SkillTag** ⭐
**Current Status:** Has Avo resource  
**Why:** Skill tags are used across the application and need management
- **Fields:** name, category
- **Associations:** interview_applications (through application_skill_tags)
- **Use Cases:**
  - Merge duplicate tags
  - Categorize tags
  - View usage statistics (how many applications use each tag)
  - Clean up unused tags
- **Actions Needed:** index, show, new, create, edit, update, destroy
- **Special Features:**
  - Usage count display
  - Popular tags sorting
  - Category filtering

#### 2. **InterviewApplication** ⭐
**Current Status:** User-facing model, no admin interface  
**Why:** Admins need to view all applications across users for support/debugging
- **Fields:** status, pipeline_stage, applied_at, notes, ai_summary
- **Associations:** user, company, job_role, job_listing, interview_rounds, skill_tags, company_feedback
- **Use Cases:**
  - View all applications across users
  - Debug issues with specific applications
  - View application statistics
  - Support user inquiries
- **Actions Needed:** index, show (read-only recommended, or limited edit)
- **Special Features:**
  - Filter by user, company, status, pipeline_stage
  - View associated rounds and feedback
  - Application timeline view

### Medium Priority

#### 3. **SyncedEmail** ⭐
**Current Status:** Has Avo resource, but could use custom admin interface  
**Why:** Email sync debugging and management
- **Fields:** subject, from_email, email_type, status, email_date
- **Associations:** user, interview_application, email_sender, connected_account
- **Use Cases:**
  - Debug email matching issues
  - View unmatched emails
  - Manually match emails to applications
  - Review email processing status
- **Actions Needed:** index, show, edit (for matching), update
- **Special Features:**
  - Filter by status (pending, processed, needs_review)
  - Filter by email_type
  - Manual matching interface
  - Bulk actions

#### 4. **ConnectedAccount** 
**Current Status:** Has Avo resource  
**Why:** OAuth debugging and token management
- **Fields:** provider, email, sync_enabled, last_synced_at, expires_at
- **Associations:** user, synced_emails
- **Use Cases:**
  - Debug OAuth connection issues
  - View token expiration status
  - Check sync status
  - View sync statistics
- **Actions Needed:** index, show (read-only recommended)
- **Special Features:**
  - Token expiration warnings
  - Sync status indicators
  - Recent sync activity

### Lower Priority (View-Only Recommended)

#### 5. **InterviewRound**
**Current Status:** Has Avo resource  
**Why:** View interview round details for debugging
- **Fields:** stage, scheduled_at, completed_at, result, notes
- **Associations:** interview_application, interview_feedback
- **Use Cases:**
  - View round details for support
  - Debug scheduling issues
- **Actions Needed:** index, show (read-only)
- **Note:** Usually accessed through InterviewApplication show page

#### 6. **CompanyFeedback**
**Current Status:** Has Avo resource  
**Why:** View feedback for support/debugging
- **Fields:** feedback_text, rejection_reason, next_steps, received_at
- **Associations:** interview_application
- **Use Cases:**
  - View feedback for support
  - Debug feedback issues
- **Actions Needed:** index, show (read-only)
- **Note:** Usually accessed through InterviewApplication show page

#### 7. **InterviewFeedback**
**Current Status:** No Avo resource found  
**Why:** View interview feedback details
- **Fields:** went_well, to_improve, interviewer_notes, ai_summary, tags
- **Associations:** interview_round
- **Use Cases:**
  - View feedback for support
- **Actions Needed:** index, show (read-only)
- **Note:** Usually accessed through InterviewRound/Application show page

## Not Recommended for Admin

### Join Tables (No direct admin needed)
- `application_skill_tags` - Managed through SkillTag/InterviewApplication
- `user_target_job_roles` - Managed through User profile
- `user_target_companies` - Managed through User profile

### Internal/System Models
- `scraped_job_listing_data` - Internal scraping data
- `transition` - Audit log for state machines
- `session` - User sessions (handled by Rails)
- `user_preference` - Managed through User settings

## Recommended Implementation Order

1. **SkillTag** - High value, simple CRUD
2. **InterviewApplication** - High value for support/debugging
3. **SyncedEmail** - Medium value, useful for email sync debugging
4. **ConnectedAccount** - Medium value, OAuth debugging
5. **InterviewRound/CompanyFeedback/InterviewFeedback** - Lower priority, view-only

## Implementation Notes

### SkillTag Admin
- Should show usage count prominently
- Allow merging tags (action to merge one tag into another)
- Category management
- Popular tags sorting

### InterviewApplication Admin
- Read-only recommended (users manage their own)
- Or limited edit (only status/pipeline_stage for support)
- Show all associations clearly
- Filter by user, company, status, pipeline_stage

### SyncedEmail Admin
- Manual matching interface (link email to application)
- Bulk actions (mark as processed, ignore)
- Filter by unmatched/needs_review
- Show email preview

### ConnectedAccount Admin
- Read-only recommended (security)
- Show token expiration warnings
- Sync statistics
- Recent sync activity

