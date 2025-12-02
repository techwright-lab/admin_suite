# frozen_string_literal: true

# Service for generating profile insights and statistics
class ProfileInsightsService
  # @param user [User] The user to generate insights for
  def initialize(user)
    @user = user
  end

  # Generates comprehensive insights for the user
  # @return [Hash] Hash containing all insights
  def generate_insights
    {
      stats: interview_stats,
      strengths: top_strengths,
      improvements: areas_to_improve,
      timeline: learning_timeline,
      recent_activity: recent_activity
    }
  end

  private

  # Interview statistics
  # @return [Hash] Statistics about applications
  def interview_stats
    applications = @user.interview_applications

    {
      total: applications.count,
      by_stage: InterviewApplication::PIPELINE_STAGES.map { |stage|
        [ stage, applications.where(pipeline_stage: stage).count ]
      }.to_h,
      with_feedback: applications.joins(interview_rounds: :interview_feedback).distinct.count,
      this_month: applications.where("created_at >= ?", 1.month.ago).count
    }
  end

  # Top strengths based on feedback
  # @return [Array<Hash>] Array of strengths with counts
  def top_strengths
    feedback_entries = InterviewFeedback.joins(interview_round: { interview_application: :user })
      .where(users: { id: @user.id })
      .where.not(went_well: nil)

    # TODO: Implement actual NLP analysis
    # For now, return placeholder data based on tags
    skill_mentions = {}

    feedback_entries.each do |entry|
      entry.tag_list.each do |tag|
        skill_mentions[tag] ||= 0
        skill_mentions[tag] += 1 if entry.went_well.present?
      end
    end

    skill_mentions.sort_by { |_k, v| -v }.first(5).map do |skill, count|
      { name: skill, count: count }
    end
  end

  # Areas to improve based on feedback
  # @return [Array<Hash>] Array of improvement areas with counts
  def areas_to_improve
    feedback_entries = InterviewFeedback.joins(interview_round: { interview_application: :user })
      .where(users: { id: @user.id })
      .where.not(to_improve: nil)

    # TODO: Implement actual NLP analysis
    # For now, return placeholder data
    skill_mentions = {}

    feedback_entries.each do |entry|
      entry.tag_list.each do |tag|
        skill_mentions[tag] ||= 0
        skill_mentions[tag] += 1 if entry.to_improve.present?
      end
    end

    skill_mentions.sort_by { |_k, v| -v }.first(5).map do |skill, count|
      { name: skill, count: count }
    end
  end

  # Learning timeline showing progress over time
  # @return [Array<Hash>] Timeline data
  def learning_timeline
    applications = @user.interview_applications.order(created_at: :asc).includes(interview_rounds: :interview_feedback)

    applications.map do |application|
      {
        date: application.created_at,
        company: application.company.name,
        role: application.job_role.title,
        stage: application.pipeline_stage,
        has_feedback: application.interview_rounds.joins(:interview_feedback).any?,
        sentiment: calculate_sentiment(application)
      }
    end
  end

  # Recent activity
  # @return [Array<Hash>] Recent activities
  def recent_activity
    activities = []

    # Recent applications
    @user.interview_applications.order(created_at: :desc).limit(5).each do |application|
      activities << {
        type: :application,
        date: application.created_at,
        description: "Added application at #{application.company.name}",
        icon: :briefcase
      }
    end

    # Recent feedback
    InterviewFeedback.joins(interview_round: { interview_application: :user })
      .where(users: { id: @user.id })
      .order(created_at: :desc)
      .limit(5)
      .includes(interview_round: { interview_application: :company })
      .each do |feedback|
        activities << {
          type: :feedback,
          date: feedback.created_at,
          description: "Added feedback for #{feedback.interview_round.interview_application.company.name}",
          icon: :document
        }
      end

    activities.sort_by { |a| a[:date] }.reverse.first(10)
  end

  # Calculate sentiment of application based on feedback
  # @param application [InterviewApplication] The application to analyze
  # @return [String] positive, neutral, or negative
  def calculate_sentiment(application)
    feedbacks = application.interview_rounds.joins(:interview_feedback).map(&:interview_feedback)
    return "neutral" unless feedbacks.any?

    # TODO: Implement actual sentiment analysis
    latest_feedback = feedbacks.sort_by(&:created_at).last

    if latest_feedback.went_well.present? && latest_feedback.to_improve.blank?
      "positive"
    elsif latest_feedback.went_well.blank? && latest_feedback.to_improve.present?
      "negative"
    else
      "neutral"
    end
  end
end
