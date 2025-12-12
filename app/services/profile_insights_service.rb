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
      skill_insights: skill_insights,
      strengths: top_strengths,
      improvements: areas_to_improve,
      timeline: learning_timeline,
      recent_activity: recent_activity
    }
  end

  # Skill-related insights from user profile
  # @return [Hash] Skill statistics and insights
  def skill_insights
    user_skills = @user.user_skills.includes(:skill_tag)

    {
      total: user_skills.count,
      strong: user_skills.strong_skills.count,
      moderate: user_skills.moderate_skills.count,
      developing: user_skills.developing_skills.count,
      top_skills: user_skills.by_level_desc.limit(5).map { |s| { name: s.skill_name, level: s.aggregated_level.round(1) } },
      categories: user_skills.group(:category).count.sort_by { |_, v| -v }.first(5).to_h,
      average_level: user_skills.average(:aggregated_level)&.round(1) || 0,
      resumes_analyzed: @user.user_resumes.analyzed.count,
      matching_target_roles: calculate_target_role_match_percentage(user_skills)
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

  # Calculate percentage of skills matching target roles
  # @param user_skills [ActiveRecord::Relation] User skills relation
  # @return [Integer] Percentage of matching skills (0-100)
  def calculate_target_role_match_percentage(user_skills)
    target_roles = @user.target_job_roles
    return 0 if target_roles.empty? || user_skills.empty?

    # Get required skills from target roles via application skill tags
    target_role_skill_ids = ApplicationSkillTag.joins(:interview_application)
      .where(interview_applications: { job_role_id: target_roles.pluck(:id) })
      .distinct
      .pluck(:skill_tag_id)

    return 0 if target_role_skill_ids.empty?

    # Calculate overlap
    user_skill_ids = user_skills.pluck(:skill_tag_id)
    matching_skills = (user_skill_ids & target_role_skill_ids).count

    ((matching_skills.to_f / target_role_skill_ids.count) * 100).round
  end
end
