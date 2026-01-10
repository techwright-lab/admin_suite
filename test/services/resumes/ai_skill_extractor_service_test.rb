# frozen_string_literal: true

require "test_helper"

class Resumes::AiSkillExtractorServiceTest < ActiveSupport::TestCase
  test "normalize_work_history_entry supports expanded schema including skills_used" do
    resume = create(:user_resume, :completed, :with_pdf_file)
    service = Resumes::AiSkillExtractorService.new(resume)

    entry = {
      "company" => "Acme Inc",
      "role" => "Senior Engineer",
      "start_date" => "2022-03",
      "end_date" => "2024-01-15",
      "current" => false,
      "responsibilities" => [ "Built APIs", "Led projects" ],
      "highlights" => [ "Shipped X", "Reduced latency" ],
      "skills_used" => [
        { "name" => "Ruby", "confidence" => 0.9, "evidence" => "Rails" },
        "PostgreSQL"
      ]
    }

    normalized = service.send(:normalize_work_history_entry, entry)
    assert_equal "Acme Inc", normalized[:company]
    assert_equal "Senior Engineer", normalized[:role]
    assert_equal Date.new(2022, 3, 1), normalized[:start_date]
    assert_equal Date.new(2024, 1, 15), normalized[:end_date]
    assert_equal false, normalized[:current]

    assert_equal [ "Built APIs", "Led projects" ], normalized[:responsibilities]
    assert_equal [ "Shipped X", "Reduced latency" ], normalized[:highlights]

    assert_equal 2, normalized[:skills_used].size
    assert_equal "Ruby", normalized[:skills_used].first[:name]
    assert_in_delta 0.9, normalized[:skills_used].first[:confidence], 0.0001
    assert_equal "Rails", normalized[:skills_used].first[:evidence]
    assert_equal "PostgreSQL", normalized[:skills_used].second[:name]
  end

  test "parse_flexible_date supports YYYY-MM-DD, YYYY-MM, and YYYY" do
    resume = create(:user_resume, :completed, :with_pdf_file)
    service = Resumes::AiSkillExtractorService.new(resume)

    assert_equal Date.new(2024, 1, 15), service.send(:parse_flexible_date, "2024-01-15")
    assert_equal Date.new(2024, 1, 1), service.send(:parse_flexible_date, "2024-01")
    assert_equal Date.new(2024, 1, 1), service.send(:parse_flexible_date, "2024")
  end

  test "extract stores structured extracted_data.resume_extraction with parsed and raw_response" do
    resume = create(:user_resume, :completed, :with_pdf_file, parsed_text: "resume text", extracted_data: {})

    # Avoid real provider calls
    service = Resumes::AiSkillExtractorService.new(resume)
    service.define_singleton_method(:extract_with_providers) do |_prompt, _content_size|
      {
        success: true,
        skills: [ { name: "Ruby", category: "Backend", proficiency: 4, confidence: 0.8 } ],
        work_history: [ { company: "Acme", role: "Engineer", duration: "2020-2021", responsibilities: [], highlights: [], skills_used: [] } ],
        summary: "Summary",
        confidence: 0.9,
        strengths: [ "Ownership" ],
        domains: [ "Backend" ],
        resume_date: Date.new(2024, 1, 1),
        resume_date_confidence: "high",
        resume_date_source: "explicit",
        provider: "openai",
        model: "gpt-test",
        raw_response: "{\"skills\":[]}"
      }
    end

    result = service.extract
    assert result[:success]

    resume.reload
    blob = resume.extracted_data["resume_extraction"]
    assert blob.present?
    assert blob["parsed"].is_a?(Hash)
    assert_equal "Summary", blob.dig("parsed", "summary")
    assert_equal "{\"skills\":[]}", blob["raw_response"]
  end

  test "extract does not crash when extracted_data is a string (legacy jsonb string) and provider returns code-fenced JSON" do
    resume = create(:user_resume, :completed, :with_pdf_file, parsed_text: "resume text", extracted_data: "legacy")

    service = Resumes::AiSkillExtractorService.new(resume)
    service.define_singleton_method(:extract_with_providers) do |_prompt, _content_size|
      {
        success: true,
        skills: [ { name: "Ruby", category: "Backend", proficiency: 4, confidence: 0.8 } ],
        work_history: [],
        summary: "Summary",
        confidence: 0.9,
        strengths: [],
        domains: [],
        resume_date: nil,
        resume_date_confidence: nil,
        resume_date_source: nil,
        provider: "anthropic",
        model: "claude-test",
        raw_response: "```json\n{\"skills\":[]}\n```"
      }
    end

    result = service.extract
    assert result[:success]

    resume.reload
    blob = resume.extracted_data["resume_extraction"]
    assert blob.present?
    assert_equal "Summary", blob.dig("parsed", "summary")
  end

  test "parse_response can parse code-fenced JSON from LLM responses" do
    resume = create(:user_resume, :completed, :with_pdf_file)
    service = Resumes::AiSkillExtractorService.new(resume)

    response = "```json\n{\"skills\":[],\"overall_confidence\":0.9}\n```"
    parsed = service.send(:parse_response, response)
    assert_in_delta 0.9, parsed[:confidence], 0.0001
  end
end
