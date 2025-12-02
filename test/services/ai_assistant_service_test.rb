# frozen_string_literal: true

require "test_helper"

class AiAssistantServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @service = AiAssistantService.new(@user, "test question")
  end

  test "#answer returns a string" do
    answer = @service.answer
    
    assert_instance_of String, answer
    assert_not_empty answer
  end

  test "handles summarize interviews query" do
    create_list(:interview, 3, user: @user)
    service = AiAssistantService.new(@user, "summarize my interviews")
    
    answer = service.answer
    
    assert_includes answer, "summary"
    assert_not_empty answer
  end

  test "handles thank you email query" do
    create(:interview, company: "TechCorp", role: "Engineer", user: @user)
    service = AiAssistantService.new(@user, "generate thank you email")
    
    answer = service.answer
    
    assert_includes answer, "TechCorp"
    assert_includes answer, "Thank you"
  end

  test "handles preparation query" do
    interview = create(:interview, user: @user)
    create(:feedback_entry, interview: interview, to_improve: "System design")
    service = AiAssistantService.new(@user, "how to prepare")
    
    answer = service.answer
    
    assert_includes answer.downcase, "prepare"
  end

  test "handles skills focus query" do
    interview = create(:interview, user: @user)
    feedback = create(:feedback_entry, interview: interview)
    feedback.update(tags: ["Ruby", "Rails"])
    service = AiAssistantService.new(@user, "what skills should I focus on")
    
    answer = service.answer
    
    assert_includes answer.downcase, "skill"
  end

  test "returns default response for unknown query" do
    service = AiAssistantService.new(@user, "random question")
    
    answer = service.answer
    
    assert_includes answer, "help you with"
  end

  test "handles case insensitive queries" do
    create(:interview, user: @user)
    service = AiAssistantService.new(@user, "SUMMARIZE MY INTERVIEWS")
    
    answer = service.answer
    
    assert_not_empty answer
  end

  test "returns message when no interviews exist for summarize" do
    service = AiAssistantService.new(@user, "summarize interviews")
    
    answer = service.answer
    
    assert_includes answer, "haven't added any interviews"
  end

  test "returns message when no interviews for thank you email" do
    service = AiAssistantService.new(@user, "thank you email")
    
    answer = service.answer
    
    assert_includes answer, "Add an interview first"
  end
end

