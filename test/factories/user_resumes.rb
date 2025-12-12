# frozen_string_literal: true

FactoryBot.define do
  factory :user_resume do
    user
    name { "#{Faker::Job.title} Resume" }
    purpose { :generic }
    analysis_status { :pending }

    trait :generic do
      purpose { :generic }
    end

    trait :company_specific do
      purpose { :company_specific }

      transient do
        companies_count { 1 }
      end

      after(:create) do |resume, evaluator|
        companies = create_list(:company, evaluator.companies_count)
        resume.target_companies = companies
      end
    end

    trait :role_specific do
      purpose { :role_specific }

      transient do
        roles_count { 1 }
      end

      after(:create) do |resume, evaluator|
        roles = create_list(:job_role, evaluator.roles_count)
        resume.target_job_roles = roles
      end
    end

    trait :with_targets do
      after(:create) do |resume|
        resume.target_job_roles = create_list(:job_role, 2)
        resume.target_companies = create_list(:company, 2)
      end
    end

    trait :pending do
      analysis_status { :pending }
    end

    trait :processing do
      analysis_status { :processing }
    end

    trait :completed do
      analysis_status { :completed }
      analyzed_at { Time.current }
      analysis_summary { "Experienced software engineer with strong backend skills." }
    end

    trait :failed do
      analysis_status { :failed }
    end

    trait :with_pdf_file do
      after(:build) do |resume|
        resume.file.attach(
          io: StringIO.new("Sample PDF content"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :with_docx_file do
      after(:build) do |resume|
        resume.file.attach(
          io: StringIO.new("Sample DOCX content"),
          filename: "resume.docx",
          content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
      end
    end

    trait :with_skills do
      completed

      transient do
        skills_count { 5 }
      end

      after(:create) do |resume, evaluator|
        create_list(:resume_skill, evaluator.skills_count, user_resume: resume)
      end
    end
  end
end
