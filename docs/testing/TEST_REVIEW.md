# Test Review & Missing Tests Report

## Current Test Status

### ✅ Tests That Exist and Pass
1. **CompanyTest** (7 tests) - ✅ All passing
2. **JobRoleTest** (7 tests) - ✅ All passing

### ❌ Tests That Need Updating
1. **UserTest** - ❌ FAILING - Uses old `current_role` field (now `current_job_role`)
2. **InterviewTest** - ❌ OUTDATED - Model renamed to `InterviewApplication`
3. **FeedbackEntryTest** - ❌ OUTDATED - Model should be `InterviewFeedback`
4. **SkillTagTest** - ⚠️ Needs update for `application_skill_tags` (was `interview_skill_tags`)
5. **UserPreferenceTest** - ⚠️ May need updates for user associations

### ✅ Tests That Exist (Generated but need review)
6. **CompanyFeedbackTest** - Generated, needs implementation
7. **InterviewRoundTest** - Generated, needs implementation
8. **JobListingTest** - Generated, needs implementation
9. **UserTargetCompanyTest** - Generated, needs implementation
10. **UserTargetJobRoleTest** - Generated, needs implementation

## Missing Tests

### Critical (New Models)
1. **InterviewApplicationTest** - ❌ MISSING
   - Should test: statuses, pipeline_stages, associations, scopes
   - Should test: card_summary, has_rounds?, latest_round, etc.

### Medium Priority
2. **InterviewFeedbackTest** - ❌ MISSING (rename from FeedbackEntryTest)
   - Should test: associations with interview_round
   - Should test: validations, scopes

3. **ApplicationSkillTagTest** - ❌ MISSING (rename from InterviewSkillTagTest)
   - Should test: join table functionality
   - Should test: uniqueness constraints

## Test Fixes Needed

### 1. UserTest Fixes
```ruby
# OLD (broken):
@user.current_role = "Software Engineer"
@user.target_roles = ["Senior Engineer", "Staff Engineer"]

# NEW (correct):
@user.current_job_role = create(:job_role, title: "Software Engineer")
@user.target_job_roles << create(:job_role, title: "Senior Engineer")
```

### 2. Update User Factory
```ruby
# OLD:
factory :user do
  current_role { "Software Engineer" }
  target_roles { ["Senior Engineer"] }
end

# NEW:
factory :user do
  association :current_job_role, factory: :job_role
  association :current_company, factory: :company
  
  trait :with_targets do
    after(:create) do |user|
      user.target_job_roles << create_list(:job_role, 2)
      user.target_companies << create_list(:company, 2)
    end
  end
end
```

### 3. Create InterviewApplicationTest
Should test:
- Status enum (active, archived, rejected, accepted)
- Pipeline stage enum (applied, screening, interviewing, offer, closed)
- Associations (user, job_listing, company, job_role, interview_rounds, etc.)
- Validations (user, company, job_role presence)
- Scopes (recent, by_status, by_pipeline_stage, active, archived)
- Methods (card_summary, has_rounds?, latest_round, completed_rounds_count, etc.)

### 4. Create InterviewRoundTest
Should test:
- Stage enum (screening, technical, hiring_manager, culture_fit, other)
- Result enum (pending, passed, failed, waitlisted)
- Associations (interview_application, interview_feedback)
- Validations (interview_application, stage presence)
- Scopes (by_stage, completed, upcoming, ordered)
- Methods (stage_display_name, completed?, upcoming?, formatted_duration)

### 5. Create JobListingTest
Should test:
- Remote type enum (on_site, hybrid, remote)
- Status enum (draft, active, closed)
- Associations (company, job_role, interview_applications)
- Validations (company, job_role presence)
- JSONB fields (custom_sections, scraped_data)
- Scopes (active, closed, remote, recent)
- Methods (display_title, salary_range, has_custom_sections?, scraped?)

### 6. Create CompanyFeedbackTest
Should test:
- Associations (interview_application)
- Validations (interview_application presence)
- Scopes (recent, with_rejection)
- Methods (rejection?, received?, summary)

### 7. Update SkillTagTest
Should test:
- Association renamed to `application_skill_tags`
- Association to `interview_applications` (not `interviews`)

## Test Coverage Goals

### Models (Priority Order)
1. ✅ Company - DONE
2. ✅ JobRole - DONE
3. ❌ InterviewApplication - CRITICAL
4. ❌ InterviewRound - CRITICAL
5. ❌ JobListing - HIGH
6. ❌ CompanyFeedback - HIGH
7. ❌ InterviewFeedback - HIGH
8. ⚠️ User - NEEDS UPDATE
9. ⚠️ SkillTag - NEEDS UPDATE
10. ⚠️ UserPreference - NEEDS REVIEW
11. ❌ UserTargetJobRole - MEDIUM
12. ❌ UserTargetCompany - MEDIUM

### Controllers (Not Yet Started)
- CompaniesController
- JobRolesController
- JobListingsController
- InterviewApplicationsController (rename from InterviewsController)
- InterviewRoundsController
- InterviewFeedbackController (rename from FeedbackEntriesController)
- CompanyFeedbackController
- ProfilesController (update for new associations)

### Integration Tests (Not Yet Started)
- Full application workflow
- Kanban board functionality
- Timeline display
- Autocomplete functionality

## Immediate Action Items

1. **Fix UserTest** - Update to use new associations
2. **Update User Factory** - Use job_role and company associations
3. **Create InterviewApplicationTest** - Critical for main model
4. **Create InterviewRoundTest** - Critical for interview rounds
5. **Create JobListingTest** - Important for job tracking
6. **Rename/Update FeedbackEntryTest** → InterviewFeedbackTest
7. **Update SkillTagTest** - Fix association names
8. **Create CompanyFeedbackTest** - Test feedback functionality
9. **Create join table tests** - UserTargetJobRole, UserTargetCompany

## Test Commands

```bash
# Run all model tests
SKIP_TAILWIND=1 bin/rails test test/models/

# Run specific test file
SKIP_TAILWIND=1 bin/rails test test/models/user_test.rb

# Run with verbose output
SKIP_TAILWIND=1 bin/rails test test/models/ --verbose

# Check test coverage (if using SimpleCov)
SKIP_TAILWIND=1 COVERAGE=true bin/rails test
```

## Notes

- Old `Interview` model tests exist but model is now `InterviewApplication`
- Old `FeedbackEntry` tests exist but should be for `InterviewFeedback`
- User model changed significantly - tests need major updates
- Many generated test files are empty and need implementation
- Factory files need to be created for all new models

