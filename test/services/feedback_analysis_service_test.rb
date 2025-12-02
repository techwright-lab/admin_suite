# frozen_string_literal: true

require "test_helper"

class FeedbackAnalysisServiceTest < ActiveSupport::TestCase
  setup do
    @feedback_entry = create(:feedback_entry)
    @service = FeedbackAnalysisService.new(@feedback_entry)
  end

  test "#analyze returns hash with expected keys" do
    result = @service.analyze
    
    assert_instance_of Hash, result
    assert_includes result.keys, :ai_summary
    assert_includes result.keys, :tags
    assert_includes result.keys, :recommended_action
  end

  test "#generate_summary returns a string" do
    summary = @service.generate_summary
    
    assert_instance_of String, summary
    assert_not_empty summary
  end

  test "#extract_tags returns an array" do
    tags = @service.extract_tags
    
    assert_instance_of Array, tags
  end

  test "#generate_recommendation returns string when to_improve present" do
    @feedback_entry.to_improve = "Need to work on system design"
    recommendation = @service.generate_recommendation
    
    assert_instance_of String, recommendation
    assert_not_empty recommendation
  end

  test "#generate_recommendation returns nil when to_improve blank" do
    @feedback_entry.to_improve = nil
    recommendation = @service.generate_recommendation
    
    assert_nil recommendation
  end

  test "extracts common skills from feedback text" do
    @feedback_entry.went_well = "Great system design and communication skills"
    @feedback_entry.to_improve = "Leadership could use work"
    
    tags = @service.extract_tags
    
    assert_includes tags, "System Design"
    assert_includes tags, "Communication"
    assert_includes tags, "Leadership"
  end
end

