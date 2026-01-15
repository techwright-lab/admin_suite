# frozen_string_literal: true

FactoryBot.define do
  factory :synced_email do
    association :user
    association :connected_account

    gmail_id { SecureRandom.hex(8) }
    thread_id { SecureRandom.hex(8) }
    from_email { "recruiter@example.com" }
    from_name { "Jane Recruiter" }
    subject { "Interview Opportunity at Example Corp" }
    snippet { "We'd like to invite you for an interview..." }
    email_date { 1.day.ago }
    status { :pending }
    email_type { "recruiter_outreach" }

    trait :scheduling do
      email_type { "scheduling" }
      subject { "Interview Confirmed - Software Engineer" }
      snippet { "Your interview has been confirmed for Monday at 2:00 PM PST..." }
      body_preview do
        <<~EMAIL
          Hi there,

          Your interview for the Software Engineer position has been confirmed!

          Date: Monday, January 20, 2026
          Time: 2:00 PM - 2:45 PM PST
          Duration: 45 minutes
          Interviewer: Sarah Chen (Senior Recruiter)
          Video Link: https://zoom.us/j/123456789

          Thanks,
          The Scheduling Team
        EMAIL
      end
    end

    trait :interview_invite do
      email_type { "interview_invite" }
      subject { "Interview Invitation - Software Engineer at TechCo" }
      snippet { "We'd like to invite you for an interview..." }
      body_preview do
        <<~EMAIL
          Hi,

          Thank you for your application. We'd like to invite you for an initial interview.

          Please use this Calendly link to schedule: https://calendly.com/recruiter/interview

          Best regards,
          TechCo Recruiting
        EMAIL
      end
    end

    trait :interview_reminder do
      email_type { "interview_reminder" }
      subject { "Reminder: Interview Tomorrow" }
      snippet { "Just a friendly reminder about your upcoming interview..." }
    end

    trait :round_feedback do
      email_type { "round_feedback" }
      subject { "Update on Your Interview" }
      snippet { "Great news! You've passed the phone screen..." }
      body_preview do
        <<~EMAIL
          Hi,

          Great news! You've successfully passed the phone screening round.

          What went well:
          - Strong problem-solving approach
          - Good communication skills

          Next steps:
          We'll be scheduling a technical interview soon.

          Best,
          HR Team
        EMAIL
      end
    end

    trait :rejection do
      email_type { "rejection" }
      subject { "Update on Your Application" }
      snippet { "Thank you for your interest. We've decided to move forward with other candidates..." }
      body_preview do
        <<~EMAIL
          Dear Candidate,

          Thank you for your interest in the Software Engineer position at Example Corp.

          After careful consideration, we have decided to move forward with other candidates
          whose experience more closely aligns with our current needs.

          We wish you the best in your job search.

          Sincerely,
          HR Team
        EMAIL
      end
    end

    trait :offer do
      email_type { "offer" }
      subject { "Job Offer - Software Engineer" }
      snippet { "Congratulations! We are thrilled to extend an offer..." }
      body_preview do
        <<~EMAIL
          Dear Candidate,

          Congratulations! We are thrilled to extend an offer for the Software Engineer position.

          Role: Software Engineer
          Base Salary: $140,000
          Start Date: February 1, 2026
          Response Deadline: January 25, 2026

          Please review the attached offer letter.

          Best,
          HR Team
        EMAIL
      end
    end

    trait :matched do
      association :interview_application
      status { :processed }
    end

    trait :with_application do
      association :interview_application
    end

    trait :processed do
      status { :processed }
    end

    trait :ignored do
      status { :ignored }
    end

    trait :auto_ignored do
      status { :auto_ignored }
    end

    trait :with_extraction do
      extraction_status { "completed" }
      extraction_confidence { 0.9 }
      extracted_at { Time.current }
      extracted_data do
        {
          "signal_company_name" => "Example Corp",
          "signal_recruiter_name" => "Jane Recruiter",
          "signal_recruiter_email" => "recruiter@example.com",
          "signal_job_title" => "Software Engineer",
          "signal_action_links" => [
            { "url" => "https://calendly.com/recruiter/interview", "action_label" => "Schedule Interview" }
          ]
        }
      end
    end
  end
end
