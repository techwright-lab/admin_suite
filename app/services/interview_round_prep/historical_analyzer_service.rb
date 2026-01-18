# frozen_string_literal: true

module InterviewRoundPrep
  # Analyzes user's historical performance on similar interview round types.
  #
  # Examines past rounds to identify:
  # - Pass rate for this type of interview
  # - Common feedback themes (strengths and areas to improve)
  # - Time patterns (average duration, recent trends)
  #
  # @example
  #   service = InterviewRoundPrep::HistoricalAnalyzerService.new(
  #     user: user,
  #     round_type: round_type
  #   )
  #   analysis = service.analyze
  class HistoricalAnalyzerService < ApplicationService
    # @param user [User]
    # @param round_type [InterviewRoundType, nil]
    def initialize(user:, round_type:)
      @user = user
      @round_type = round_type
    end

    # Analyzes historical performance
    #
    # @return [Hash]
    def analyze
      return empty_analysis if past_rounds.empty?

      {
        total_rounds: past_rounds.count,
        completed_rounds: completed_rounds.count,
        pass_rate: calculate_pass_rate,
        performance_trend: performance_trend,
        feedback_themes: feedback_themes,
        common_strengths: common_strengths,
        areas_to_improve: areas_to_improve,
        average_duration_minutes: average_duration
      }.compact
    end

    private

    attr_reader :user, :round_type

    # @return [ActiveRecord::Relation]
    def past_rounds
      @past_rounds ||= begin
        scope = InterviewRound
          .joins(interview_application: :user)
          .where(interview_applications: { user_id: user.id })

        if round_type
          scope = scope.where(interview_round_type_id: round_type.id)
        end

        scope.order(created_at: :desc).limit(50)
      end
    end

    # @return [ActiveRecord::Relation]
    def completed_rounds
      @completed_rounds ||= past_rounds.where.not(completed_at: nil)
    end

    # @return [Float, nil]
    def calculate_pass_rate
      return nil if completed_rounds.empty?

      passed = completed_rounds.where(result: :passed).count
      total = completed_rounds.count

      return nil if total.zero?

      (passed.to_f / total * 100).round(1)
    end

    # Analyzes recent performance trend
    #
    # @return [String, nil]
    def performance_trend
      recent = completed_rounds.limit(5)
      return nil if recent.count < 3

      recent_results = recent.pluck(:result)
      passed_count = recent_results.count("passed")

      if passed_count >= 4
        "strong"
      elsif passed_count >= 3
        "positive"
      elsif passed_count >= 2
        "mixed"
      else
        "needs_improvement"
      end
    end

    # Extracts feedback themes from past round feedback
    #
    # @return [Array<Hash>]
    def feedback_themes
      feedbacks = InterviewFeedback
        .joins(interview_round: :interview_application)
        .where(interview_applications: { user_id: user.id })

      if round_type
        feedbacks = feedbacks.joins(:interview_round)
          .where(interview_rounds: { interview_round_type_id: round_type.id })
      end

      feedbacks = feedbacks.order(created_at: :desc).limit(20)

      # Extract tags and count frequencies
      tags = feedbacks.flat_map(&:tag_list).map(&:to_s).map(&:strip).reject(&:blank?)
      tag_counts = tags.each_with_object(Hash.new(0)) { |t, h| h[t] += 1 }

      tag_counts.sort_by { |_k, v| -v }.first(10).map do |tag, count|
        { tag: tag, count: count }
      end
    end

    # Identifies common strengths from feedback
    #
    # @return [Array<String>]
    def common_strengths
      # Look for positive patterns in feedback went_well field
      feedbacks = InterviewFeedback
        .joins(interview_round: :interview_application)
        .where(interview_applications: { user_id: user.id })
        .where.not(went_well: [ nil, "" ])

      if round_type
        feedbacks = feedbacks.joins(:interview_round)
          .where(interview_rounds: { interview_round_type_id: round_type.id })
      end

      # Extract from tags that indicate strengths
      strength_tags = feedbacks.flat_map(&:tag_list)
        .map(&:to_s)
        .select { |t| t.match?(/strong|good|excellent|clear|effective/i) }

      strength_tags.uniq.first(5)
    end

    # Identifies areas that need improvement
    #
    # @return [Array<String>]
    def areas_to_improve
      # Look for patterns in to_improve field
      feedbacks = InterviewFeedback
        .joins(interview_round: :interview_application)
        .where(interview_applications: { user_id: user.id })
        .where.not(to_improve: [ nil, "" ])

      if round_type
        feedbacks = feedbacks.joins(:interview_round)
          .where(interview_rounds: { interview_round_type_id: round_type.id })
      end

      # Extract from tags that indicate improvement areas
      improvement_tags = feedbacks.flat_map(&:tag_list)
        .map(&:to_s)
        .reject { |t| t.match?(/strong|good|excellent/i) }

      improvement_tags.uniq.first(5)
    end

    # @return [Integer, nil]
    def average_duration
      durations = completed_rounds.where.not(duration_minutes: nil).pluck(:duration_minutes)
      return nil if durations.empty?

      (durations.sum.to_f / durations.size).round
    end

    # @return [Hash]
    def empty_analysis
      {
        total_rounds: 0,
        completed_rounds: 0,
        note: "No historical data available for this round type"
      }
    end
  end
end
