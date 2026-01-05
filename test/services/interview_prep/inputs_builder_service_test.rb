# frozen_string_literal: true

require "test_helper"

class InterviewPrep::InputsBuilderServiceTest < ActiveSupport::TestCase
  test "job_listing is the primary job context and supplemental text is included when present" do
    user = create(:user)
    create(:user_skill, user: user, skill_tag: create(:skill_tag, name: "Ruby"))

    job_listing = create(:job_listing, title: "Backend Engineer", description: "Build APIs", requirements: "Ruby, Postgres")
    application = create(:interview_application, user: user, job_listing: job_listing, job_description_text: "Extra context from recruiter")

    inputs = InterviewPrep::InputsBuilderService.new(user: user, interview_application: application).build
    job_ctx = inputs[:job_context]

    assert_equal application.display_company.name, job_ctx[:company]
    assert_equal application.display_job_role.title, job_ctx[:role]
    assert_equal "Extra context from recruiter", job_ctx[:supplemental_job_text]

    extracted = job_ctx[:extracted_job_listing]
    assert extracted.is_a?(Hash)
    assert_equal "Backend Engineer", extracted[:title]
    assert_equal "Build APIs", extracted[:description]
    assert_equal "Ruby, Postgres", extracted[:requirements]
  end

  test "when no job_listing exists, extracted_job_listing is empty and supplemental text can still drive prep" do
    user = create(:user)
    application = create(:interview_application, user: user, job_listing: nil, job_description_text: "Pasted JD")

    inputs = InterviewPrep::InputsBuilderService.new(user: user, interview_application: application).build
    job_ctx = inputs[:job_context]

    assert_equal({}, job_ctx[:extracted_job_listing])
    assert_equal "Pasted JD", job_ctx[:supplemental_job_text]
  end
end
