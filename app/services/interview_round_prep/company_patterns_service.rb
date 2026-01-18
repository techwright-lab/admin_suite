# frozen_string_literal: true

module InterviewRoundPrep
  # Aggregates company-specific interview patterns from historical data.
  #
  # Analyzes interview data from all users who interviewed at the same company
  # to identify:
  # - Common round sequences
  # - Typical interview formats and durations
  # - Success factors
  # - Question themes (anonymized)
  #
  # @example
  #   service = InterviewRoundPrep::CompanyPatternsService.new(
  #     company: company,
  #     round_type: round_type
  #   )
  #   patterns = service.analyze
  class CompanyPatternsService < ApplicationService
    # @param company [Company]
    # @param round_type [InterviewRoundType, nil]
    def initialize(company:, round_type:)
      @company = company
      @round_type = round_type
    end

    # Analyzes company interview patterns
    #
    # @return [Hash]
    def analyze
      return empty_analysis if company.nil? || company_rounds.empty?

      {
        company_name: company.name,
        total_interviews: company_applications.count,
        round_type_data: round_type_patterns,
        typical_process: typical_interview_process,
        success_indicators: success_indicators,
        average_duration_minutes: average_duration,
        interview_style_hints: interview_style_hints
      }.compact
    end

    private

    attr_reader :company, :round_type

    # @return [ActiveRecord::Relation]
    def company_applications
      @company_applications ||= InterviewApplication.where(company: company)
    end

    # @return [ActiveRecord::Relation]
    def company_rounds
      @company_rounds ||= InterviewRound
        .joins(:interview_application)
        .where(interview_applications: { company_id: company.id })
    end

    # @return [ActiveRecord::Relation]
    def type_specific_rounds
      return company_rounds unless round_type

      @type_specific_rounds ||= company_rounds.where(interview_round_type_id: round_type.id)
    end

    # Patterns specific to the round type at this company
    #
    # @return [Hash, nil]
    def round_type_patterns
      return nil unless round_type

      type_rounds = type_specific_rounds
      return nil if type_rounds.empty?

      completed = type_rounds.where.not(completed_at: nil)
      passed = completed.where(result: :passed)

      {
        round_type_name: round_type.name,
        total_at_company: type_rounds.count,
        pass_rate: completed.any? ? (passed.count.to_f / completed.count * 100).round(1) : nil,
        common_position: most_common_position(type_rounds)
      }.compact
    end

    # Identifies the typical interview process at this company
    #
    # @return [Hash]
    def typical_interview_process
      # Count rounds per application
      round_counts = company_applications
        .joins(:interview_rounds)
        .group("interview_applications.id")
        .count("interview_rounds.id")

      avg_rounds = round_counts.values.any? ? (round_counts.values.sum.to_f / round_counts.size).round(1) : nil

      # Common stage sequence
      stage_sequence = company_rounds
        .order(:position)
        .pluck(:stage)
        .uniq

      {
        average_rounds: avg_rounds,
        typical_stages: stage_sequence.first(6),
        total_applications_analyzed: company_applications.count
      }.compact
    end

    # Identifies success indicators from applications that received offers
    #
    # @return [Hash]
    def success_indicators
      successful_apps = company_applications.where(pipeline_stage: :offer)
      return nil if successful_apps.empty?

      successful_rounds = InterviewRound
        .joins(:interview_application)
        .where(interview_applications: { id: successful_apps.select(:id) })
        .where.not(completed_at: nil)

      # Common tags from successful interview feedback
      feedbacks = InterviewFeedback
        .joins(interview_round: :interview_application)
        .where(interview_applications: { id: successful_apps.select(:id) })

      success_tags = feedbacks.flat_map(&:tag_list).map(&:to_s).map(&:strip).reject(&:blank?)
      tag_counts = success_tags.each_with_object(Hash.new(0)) { |t, h| h[t] += 1 }
      top_tags = tag_counts.sort_by { |_k, v| -v }.first(5).map { |tag, _| tag }

      {
        successful_applications: successful_apps.count,
        success_rate: (successful_apps.count.to_f / company_applications.count * 100).round(1),
        common_success_factors: top_tags
      }.compact
    end

    # @return [Integer, nil]
    def average_duration
      durations = type_specific_rounds.where.not(duration_minutes: nil).pluck(:duration_minutes)
      return nil if durations.empty?

      (durations.sum.to_f / durations.size).round
    end

    # Infers interview style from available data
    #
    # @return [Array<String>]
    def interview_style_hints
      hints = []

      # Check for video links (remote interviews)
      video_count = type_specific_rounds.where.not(video_link: nil).count
      if video_count > type_specific_rounds.count / 2
        hints << "Often conducted remotely"
      end

      # Check for multiple interviewer mentions
      panel_rounds = type_specific_rounds.where("interview_rounds.notes ILIKE ?", "%panel%")
      if panel_rounds.any?
        hints << "May include panel interviews"
      end

      # Check typical duration patterns
      avg_dur = average_duration
      if avg_dur
        if avg_dur >= 60
          hints << "Typically extended sessions (60+ min)"
        elsif avg_dur <= 30
          hints << "Usually quick sessions (30 min or less)"
        end
      end

      hints
    end

    # @param rounds [ActiveRecord::Relation]
    # @return [Integer, nil]
    def most_common_position(rounds)
      positions = rounds.where.not(position: nil).pluck(:position)
      return nil if positions.empty?

      positions.group_by(&:itself).max_by { |_, v| v.size }&.first
    end

    # @return [Hash]
    def empty_analysis
      {
        note: "Limited company data available",
        total_interviews: 0
      }
    end
  end
end
