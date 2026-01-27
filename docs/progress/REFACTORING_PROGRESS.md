# Interview System Refactoring Progress

## Completed Tasks

### 1. New Models Created ✅

#### Company Model
- Fields: name, website, about, logo_url
- Associations: job_listings, interview_applications, users (current & target)
- Validations: name presence and uniqueness

#### JobRole Model  
- Fields: title, category, description
- Associations: job_listings, interview_applications, users (current & target)
- Validations: title presence and uniqueness

#### JobListing Model
- Core fields: title, description, requirements, responsibilities, url, source_id, job_board_id
- Compensation: salary_min, salary_max, salary_currency, equity_info
- Additional: benefits, perks, location, remote_type (enum), status (enum)
- JSON fields: custom_sections (jsonb), scraped_data (jsonb)
- Associations: company, job_role, interview_applications

#### InterviewRound Model
- Fields: stage (enum), stage_name, scheduled_at, completed_at, duration_minutes
- Interviewer: interviewer_name, interviewer_role
- Fields: notes, result (enum), position
- Stages: screening, technical, hiring_manager, culture_fit, other
- Results: pending, passed, failed, waitlisted
- Association: interview_application, interview_feedback

#### CompanyFeedback Model
- Fields: feedback_text, received_at, rejection_reason, next_steps, self_reflection
- Association: interview_application

#### UserTargetJobRole & UserTargetCompany (Join Tables)
- Fields: user_id, job_role_id/company_id, priority
- Unique indexes on user + role/company combinations

### 2. Model Renames ✅

#### Interview → InterviewApplication
- Table: `interview_applications`
- Model: `InterviewApplication`
- New fields: job_listing_id, company_id, job_role_id, applied_at
- Renamed: stage → status (enum: active, archived, rejected, accepted)
- Associations: user, job_listing, company, job_role, interview_rounds, application_skill_tags, skill_tags, company_feedback

### 3. User Model Updates ✅

#### Removed Fields:
- `current_role` (string)
- `target_roles` (JSON)

#### Added Associations:
- `belongs_to :current_job_role` (optional)
- `belongs_to :current_company` (optional)
- `has_many :user_target_job_roles`
- `has_many :target_job_roles, through: :user_target_job_roles`
- `has_many :user_target_companies`
- `has_many :target_companies, through: :user_target_companies`
- `has_many :interview_applications` (was interviews)
- `has_many :interview_rounds, through: :interview_applications`

### 4. Migrations Created ✅

1. `CreateCompanies` - companies table
2. `CreateJobRoles` - job_roles table
3. `CreateUserTargetJobRoles` - join table with unique index
4. `CreateUserTargetCompanies` - join table with unique index
5. `AddCurrentJobRoleAndCompanyToUsers` - foreign keys to users, removes old fields
6. `CreateJobListings` - job_listings table with all fields
7. `RenameInterviewsToApplications` - renames table, adds new columns
8. `CreateInterviewRounds` - interview_rounds table
9. `CreateCompanyFeedbacks` - company_feedbacks table

## Pending Tasks

### High Priority
1. **Rename FeedbackEntry → InterviewFeedback** (in progress)
2. **Rename interview_skill_tags → application_skill_tags**
3. **Create data migration** to migrate existing interview data
4. **Update SkillTag model** associations

### Medium Priority
5. **Create/Update Controllers:**
   - CompaniesController (index, create for autocomplete)
   - JobRolesController (index, create for autocomplete)
   - JobListingsController (full CRUD)
   - InterviewApplicationsController (rename from InterviewsController)
   - InterviewRoundsController (nested under applications)
   - InterviewFeedbackController (rename from FeedbackEntriesController)
   - CompanyFeedbackController (new)
   - Update ProfilesController for new associations

6. **Update Routes** - nested resources structure

### Lower Priority
7. **Create Views:**
   - Application forms with company/role autocomplete
   - Job listing forms with dynamic sections
   - Interview round forms
   - Timeline component
   - Update all interview views to application views

8. **Create Stimulus Controllers:**
   - autocomplete_controller.js
   - timeline_controller.js
   - dynamic_sections_controller.js

9. **Update Tests & Factories:**
   - Create factories for all new models
   - Update existing factories
   - Update all tests

10. **Update Services:**
    - FeedbackAnalysisService
    - ProfileInsightsService
    - Create JobListingScraperService
    - Create ApplicationTimelineService

## Database Schema Overview

```
users
  - current_job_role_id → job_roles
  - current_company_id → companies
  
companies
  - name (unique)
  - website, about, logo_url

job_roles
  - title (unique)
  - category, description

job_listings
  - company_id → companies
  - job_role_id → job_roles
  - title, url, source_id, job_board_id
  - description, requirements, responsibilities
  - salary_min, salary_max, salary_currency, equity_info
  - benefits, perks, location
  - remote_type (enum), status (enum)
  - custom_sections (jsonb), scraped_data (jsonb)

interview_applications (was interviews)
  - user_id → users
  - job_listing_id → job_listings (optional)
  - company_id → companies
  - job_role_id → job_roles
  - status (enum: active, archived, rejected, accepted)
  - applied_at, notes, ai_summary

interview_rounds
  - interview_application_id → interview_applications
  - stage (enum), stage_name
  - scheduled_at, completed_at, duration_minutes
  - interviewer_name, interviewer_role
  - notes, result (enum), position

company_feedbacks
  - interview_application_id → interview_applications
  - feedback_text, received_at
  - rejection_reason, next_steps, self_reflection

user_target_job_roles
  - user_id → users
  - job_role_id → job_roles
  - priority

user_target_companies
  - user_id → users
  - company_id → companies
  - priority
```

## Next Steps

1. Test migrations: `bin/rails db:migrate`
2. Complete FeedbackEntry → InterviewFeedback rename
3. Rename join table for skill tags
4. Create data migration for existing records
5. Update controllers and routes
6. Update views
7. Update tests

## Notes

- Using `InterviewApplication` as model name to avoid conflict with Rails' `Application` class
- Table name is `interview_applications` (not `applications`)
- All foreign keys use `interview_application_id`
- JobRole (not Role) to avoid future conflicts with user roles/permissions
- Custom sections in JobListing stored as JSONB for flexibility

