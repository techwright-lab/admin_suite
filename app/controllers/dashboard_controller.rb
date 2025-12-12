# frozen_string_literal: true

# Controller for the user dashboard
#
# Provides a minimalistic overview with quick actions, attention items,
# recent activity, and pipeline summary.
class DashboardController < ApplicationController
  # GET /dashboard
  #
  # Main dashboard view for authenticated users
  def index
    @user = Current.user
    @quick_stats = calculate_quick_stats
    @needs_attention = calculate_needs_attention
    @recent_activity = recent_activity_feed
    @pipeline_summary = pipeline_summary
    @upcoming_interviews = upcoming_interviews
  end

  private

  # Calculates quick stats for the dashboard header
  #
  # @return [Hash] Stats data
  def calculate_quick_stats
    {
      active_applications: Current.user.interview_applications.where(status: :active).count,
      total_applications: Current.user.interview_applications.count,
      interviews_this_week: interviews_this_week_count,
      emails_to_review: Current.user.synced_emails.needs_review.count,
      skills_count: Current.user.user_skills.count,
      resumes_count: Current.user.user_resumes.count
    }
  end

  # Calculates items that need user attention
  #
  # @return [Array<Hash>] Attention items with type, count, message, and path
  def calculate_needs_attention
    items = []

    # Emails needing review
    email_count = Current.user.synced_emails.needs_review.count
    if email_count > 0
      items << {
        type: :emails,
        count: email_count,
        message: "#{email_count} #{'email'.pluralize(email_count)} need review",
        path: inbox_index_path,
        icon: "mail",
        color: "amber"
      }
    end

    # Upcoming interviews this week
    interview_count = interviews_this_week_count
    if interview_count > 0
      items << {
        type: :interviews,
        count: interview_count,
        message: "#{interview_count} #{'interview'.pluralize(interview_count)} this week",
        path: interview_applications_path,
        icon: "calendar",
        color: "blue"
      }
    end

    # Stale applications (no activity in 14+ days)
    stale_count = stale_applications_count
    if stale_count > 0
      items << {
        type: :stale,
        count: stale_count,
        message: "#{stale_count} #{'application'.pluralize(stale_count)} need follow-up",
        path: interview_applications_path,
        icon: "clock",
        color: "orange"
      }
    end

    # Actionable opportunities (new or reviewing)
    opportunity_count = Current.user.opportunities.actionable.count
    if opportunity_count > 0
      items << {
        type: :opportunities,
        count: opportunity_count,
        message: "#{opportunity_count} new #{'opportunity'.pluralize(opportunity_count)}",
        path: opportunities_path,
        icon: "sparkles",
        color: "purple"
      }
    end

    items
  end

  # Builds recent activity feed
  #
  # @return [Array<Hash>] Recent activity items
  def recent_activity_feed
    activities = []

    # Recent applications (last 5)
    Current.user.interview_applications.recent.limit(5).each do |app|
      activities << {
        type: :application,
        title: "Applied to #{app.job_role.title}",
        subtitle: app.company.name,
        timestamp: app.applied_at || app.created_at,
        path: interview_application_path(app),
        icon: "briefcase"
      }
    end

    # Recent interview rounds (last 5)
    Current.user.interview_rounds
      .joins(:interview_application)
      .where(interview_applications: { user_id: Current.user.id })
      .order(created_at: :desc)
      .limit(5)
      .includes(interview_application: [ :company, :job_role ])
      .each do |round|
        app = round.interview_application
        activities << {
          type: :interview,
          title: "#{round.stage_display_name} interview",
          subtitle: "#{app.company.name} - #{app.job_role.title}",
          timestamp: round.scheduled_at || round.created_at,
          path: interview_application_path(app),
          icon: "video-camera"
        }
      end

    # Sort by timestamp and take top 5
    activities.sort_by { |a| a[:timestamp] || Time.at(0) }.reverse.first(5)
  end

  # Calculates pipeline summary by stage
  #
  # @return [Hash] Pipeline counts by stage
  def pipeline_summary
    base = Current.user.interview_applications.where(status: :active)

    {
      applied: base.where(pipeline_stage: :applied).count,
      screening: base.where(pipeline_stage: :screening).count,
      interviewing: base.where(pipeline_stage: :interviewing).count,
      offer: base.where(pipeline_stage: :offer).count,
      closed: base.where(pipeline_stage: :closed).count,
      total: base.count
    }
  end

  # Returns upcoming interviews (next 7 days)
  #
  # @return [ActiveRecord::Relation]
  def upcoming_interviews
    Current.user.interview_rounds
      .joins(:interview_application)
      .where(interview_applications: { user_id: Current.user.id })
      .where("scheduled_at > ? AND scheduled_at < ?", Time.current, 7.days.from_now)
      .where(completed_at: nil)
      .order(scheduled_at: :asc)
      .includes(interview_application: [ :company, :job_role ])
      .limit(5)
  end

  # Counts interviews scheduled this week
  #
  # @return [Integer]
  def interviews_this_week_count
    Current.user.interview_rounds
      .joins(:interview_application)
      .where(interview_applications: { user_id: Current.user.id })
      .where("scheduled_at >= ? AND scheduled_at <= ?", Time.current.beginning_of_week, Time.current.end_of_week)
      .where(completed_at: nil)
      .count
  end

  # Counts stale applications (no activity in 14+ days)
  #
  # @return [Integer]
  def stale_applications_count
    Current.user.interview_applications
      .where(status: :active)
      .where("updated_at < ?", 14.days.ago)
      .count
  end
end

