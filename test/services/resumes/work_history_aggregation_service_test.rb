# frozen_string_literal: true

require "test_helper"

class Resumes::WorkHistoryAggregationServiceTest < ActiveSupport::TestCase
  test "merges resume experiences across resumes into user work experiences with provenance and aggregated skills" do
    user = create(:user)

    resume1 = create(:user_resume, :with_pdf_file, user: user, analysis_status: :completed, analyzed_at: Time.current)
    resume2 = create(:user_resume, :with_pdf_file, user: user, analysis_status: :completed, analyzed_at: Time.current)

    ruby = SkillTag.find_or_create_by_name("Ruby")
    pg = SkillTag.find_or_create_by_name("PostgreSQL")

    exp1 = ResumeWorkExperience.create!(
      user_resume: resume1,
      company_name: "Acme",
      role_title: "Engineer",
      start_date: Date.new(2020, 1, 1),
      end_date: Date.new(2021, 12, 31),
      current: false,
      responsibilities: [ "Built APIs" ],
      highlights: [ "Shipped X" ],
      metadata: {}
    )
    ResumeWorkExperienceSkill.create!(resume_work_experience: exp1, skill_tag: ruby)

    exp2 = ResumeWorkExperience.create!(
      user_resume: resume2,
      company_name: "Acme",
      role_title: "Engineer",
      start_date: Date.new(2022, 1, 1),
      end_date: nil,
      current: true,
      responsibilities: [ "Owned services" ],
      highlights: [ "Improved latency" ],
      metadata: {}
    )
    ResumeWorkExperienceSkill.create!(resume_work_experience: exp2, skill_tag: ruby)
    ResumeWorkExperienceSkill.create!(resume_work_experience: exp2, skill_tag: pg)

    Resumes::WorkHistoryAggregationService.new(user).run

    uwe = UserWorkExperience.where(user: user).first
    assert uwe.present?
    assert_equal "Acme", uwe.company_name
    assert_equal "Engineer", uwe.role_title
    assert_equal true, uwe.current
    assert_equal 2, uwe.source_count

    # Provenance
    assert_equal 2, uwe.user_work_experience_sources.count

    # Aggregated skills
    uwe_skill_names = uwe.skill_tags.pluck(:name)
    assert_includes uwe_skill_names.map(&:downcase), "ruby"
    assert_includes uwe_skill_names.map(&:downcase), "postgresql"

    ruby_row = uwe.user_work_experience_skills.joins(:skill_tag).find_by(skill_tags: { name: "Ruby" })
    assert_equal 2, ruby_row.source_count
  end
end
