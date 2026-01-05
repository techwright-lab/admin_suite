# frozen_string_literal: true

require "test_helper"

class ProfileInsightsServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @service = ProfileInsightsService.new(@user)
  end

  test "#generate_insights returns hash with expected keys" do
    result = @service.generate_insights
    
    assert_instance_of Hash, result
    assert_includes result.keys, :stats
    assert_includes result.keys, :strengths
    assert_includes result.keys, :improvements
    assert_includes result.keys, :timeline
    assert_includes result.keys, :recent_activity
  end

  test "stats includes correct interview counts" do
    create_list(:interview_application, 3, :applied_stage, user: @user)
    create_list(:interview_application, 2, :offer_stage, user: @user)
    
    insights = @service.generate_insights
    stats = insights[:stats]
    
    assert_equal 5, stats[:total]
    assert_equal 3, stats[:by_stage][:applied]
    assert_equal 2, stats[:by_stage][:offer]
  end

  test "stats includes feedback count" do
    application1 = create(:interview_application, :with_rounds, user: @user)
    application1.interview_rounds.each { |round| create(:interview_feedback, interview_round: round) }
    create(:interview_application, user: @user)
    
    insights = @service.generate_insights
    stats = insights[:stats]
    
    # with_feedback counts distinct applications that have feedback, not individual feedback entries
    assert_equal 1, stats[:with_feedback] # 1 application with feedback
  end

  test "strengths based on positive feedback tags" do
    application = create(:interview_application, user: @user)
    round = create(:interview_round, interview_application: application)
    feedback = create(:interview_feedback, interview_round: round, tags: ["Ruby", "Rails", "Testing"])
    
    insights = @service.generate_insights
    strengths = insights[:strengths]
    
    assert_instance_of Array, strengths
  end

  test "timeline shows interview progression" do
    create_list(:interview_application, 3, user: @user)
    
    insights = @service.generate_insights
    timeline = insights[:timeline]
    
    assert_equal 3, timeline.length
    assert timeline.all? { |item| item.key?(:date) }
    assert timeline.all? { |item| item.key?(:company) }
    assert timeline.all? { |item| item.key?(:sentiment) }
  end

  test "recent_activity combines interviews and feedback" do
    create(:interview_application, user: @user)
    application = create(:interview_application, user: @user)
    round = create(:interview_round, interview_application: application)
    create(:interview_feedback, interview_round: round)
    
    insights = @service.generate_insights
    activity = insights[:recent_activity]
    
    assert_instance_of Array, activity
    assert activity.length >= 2
    assert activity.all? { |item| item.key?(:type) }
    assert activity.all? { |item| item.key?(:date) }
  end
end

