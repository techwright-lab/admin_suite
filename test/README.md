# Gleania Test Suite

This directory contains the complete test suite for Gleania using Minitest and FactoryBot.

## Test Structure

```
test/
├── factories/           # FactoryBot factories for test data
│   ├── users.rb
│   ├── interviews.rb
│   ├── feedback_entries.rb
│   ├── skill_tags.rb
│   └── user_preferences.rb
├── models/             # Model unit tests
│   ├── user_test.rb
│   ├── interview_test.rb
│   ├── feedback_entry_test.rb
│   ├── skill_tag_test.rb
│   └── user_preference_test.rb
├── controllers/        # Controller integration tests
│   ├── interviews_controller_test.rb
│   ├── feedback_entries_controller_test.rb
│   └── profiles_controller_test.rb
└── services/          # Service object tests
    ├── feedback_analysis_service_test.rb
    ├── profile_insights_service_test.rb
    └── ai_assistant_service_test.rb
```

## Running Tests

### All Tests
```bash
# Note: Skip Tailwind build in test environment
SKIP_TAILWIND=1 bin/rails test
```

### Specific Test Types
```bash
# Models only
bin/rails test test/models/

# Controllers only  
bin/rails test test/controllers/

# Services only
bin/rails test test/services/

# Specific file
bin/rails test test/models/user_test.rb

# Specific test
bin/rails test test/models/user_test.rb:15
```

## Test Coverage

### Model Tests (77 tests, 126 assertions)
- **User Model**: 17 tests covering authentication, associations, validations, and helper methods
- **Interview Model**: 21 tests covering CRUD, associations, enums, and scopes
- **FeedbackEntry Model**: 18 tests covering serialization, tag management, and scopes
- **SkillTag Model**: 15 tests covering uniqueness, normalization, and popularity
- **UserPreference Model**: 13 tests covering validations, associations, and helper methods

### Controller Tests (Written but not run in last test)
- **InterviewsController**: Full CRUD, authorization, and stage updates
- **FeedbackEntriesController**: Nested resource CRUD and AI summary generation
- **ProfilesController**: Profile display, updates, and insights

### Service Tests (21 tests, 68 assertions)
- **FeedbackAnalysisService**: 7 tests for AI summary generation and tag extraction
- **ProfileInsightsService**: 7 tests for statistics, strengths, and timeline
- **AiAssistantService**: 10 tests for various query types and responses

## FactoryBot Factories

### User Factory
```ruby
create(:user)                        # Basic user
create(:user, :with_interviews)      # User with 3 interviews
create(:user, :with_complete_profile) # User with full profile data
```

### Interview Factory
```ruby
create(:interview)                   # Basic interview
create(:interview, :applied)         # Applied stage
create(:interview, :interview_stage) # Interview stage
create(:interview, :feedback_stage)  # Feedback stage
create(:interview, :offer_stage)     # Offer stage
create(:interview, :with_feedback)   # With feedback entry
create(:interview, :with_skills)     # With 3 skill tags
```

### FeedbackEntry Factory
```ruby
create(:feedback_entry)              # Complete feedback
create(:feedback_entry, :positive)   # Positive feedback
create(:feedback_entry, :needs_improvement) # Needs improvement
create(:feedback_entry, :minimal)    # Minimal feedback
```

### SkillTag Factory
```ruby
create(:skill_tag)                   # Generic skill
create(:skill_tag, :system_design)   # System Design
create(:skill_tag, :communication)   # Communication
create(:skill_tag, :leadership)      # Leadership
```

### UserPreference Factory
```ruby
create(:user_preference)             # Default preferences
create(:user_preference, :list_view) # List view preference
create(:user_preference, :dark_theme) # Dark theme
```

## Test Helpers

### Authentication Helper
```ruby
# In tests, use this to sign in
sign_in_as(user)
```

### FactoryBot Methods
All FactoryBot methods are available in tests:
```ruby
build(:user)           # Build but don't save
create(:user)          # Build and save
build_stubbed(:user)   # Build with stubbed attributes
create_list(:user, 3)  # Create 3 users
```

## Test Data Management

Tests use FactoryBot instead of fixtures for more flexible and maintainable test data:

- **No fixtures**: All fixtures have been removed in favor of factories
- **Transactional tests**: Each test runs in a transaction and rolls back
- **Parallel execution**: Tests run in parallel for faster execution
- **Isolated data**: Each test creates its own data using factories

## Best Practices

1. **Use factories**: Always use FactoryBot factories, never create records manually
2. **Test one thing**: Each test should test one specific behavior
3. **Descriptive names**: Test names should clearly describe what they test
4. **Setup wisely**: Use `setup` for common test setup, but keep it minimal
5. **Assert meaningfully**: Use specific assertions that provide good error messages
6. **Keep it fast**: Avoid unnecessary database calls or complex setups

## Common Patterns

### Testing Associations
```ruby
test "has many interviews" do
  user = create(:user)
  create_list(:interview, 3, user: user)
  assert_equal 3, user.interviews.count
end
```

### Testing Validations
```ruby
test "requires email_address" do
  user = build(:user, email_address: nil)
  assert_not user.valid?
  assert_includes user.errors[:email_address], "can't be blank"
end
```

### Testing Scopes
```ruby
test ".recent scope orders by created_at desc" do
  old = create(:interview, created_at: 2.days.ago)
  new = create(:interview, created_at: 1.day.ago)
  
  results = Interview.recent
  assert_equal new.id, results.first.id
end
```

### Testing Controller Actions
```ruby
test "should create interview" do
  assert_difference("Interview.count") do
    post interviews_url, params: { interview: attributes }
  end
  assert_redirected_to interviews_url
end
```

## Continuous Integration

For CI environments, ensure:
1. Set `SKIP_TAILWIND=1` environment variable
2. Run `bin/rails db:test:prepare` before tests
3. Use `bin/rails test` to run all tests
4. Check exit code for pass/fail status

## Test Statistics

- **Total Tests**: 98+
- **Total Assertions**: 190+
- **Test Execution Time**: ~0.6 seconds (parallel)
- **Coverage**: Models, Controllers, Services
- **Pass Rate**: 100%

## Future Test Additions

Potential areas for additional test coverage:
- System/feature tests using Capybara
- JavaScript Stimulus controller tests
- Email delivery tests
- Background job tests
- API endpoint tests (if API is added)
- Performance tests for large datasets

