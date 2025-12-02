# frozen_string_literal: true

# Service for generating timeline data for an interview application
#
# @example
#   service = ApplicationTimelineService.new(interview_application)
#   timeline = service.generate
#
class ApplicationTimelineService
  # Initialize the service with an interview application
  #
  # @param [InterviewApplication] interview_application The application to generate timeline for
  def initialize(interview_application)
    @application = interview_application
  end

  # Generates timeline data for the application
  #
  # @return [Array<Hash>] Array of timeline events
  def generate
    events = []

    # Add application submission event
    events << application_event

    # Add interview round events
    events.concat(interview_round_events)

    # Add email events
    events.concat(email_events)

    # Add company feedback event
    events << company_feedback_event if @application.company_feedback.present?

    # Add status change events (if we track them in the future)
    # events.concat(status_change_events)

    # Sort by date
    events.sort_by { |e| e[:date] || Time.current }
  end

  # Returns timeline as grouped by month
  #
  # @return [Hash] Timeline events grouped by month
  def generate_grouped
    generate.group_by { |event| event[:date].beginning_of_month }
  end

  # Returns summary statistics for the timeline
  #
  # @return [Hash] Summary statistics
  def summary
    {
      total_events: generate.count,
      total_rounds: @application.interview_rounds.count,
      completed_rounds: @application.completed_rounds_count,
      pending_rounds: @application.pending_rounds_count,
      total_emails: @application.synced_emails.count,
      days_since_application: days_since_application,
      has_feedback: @application.has_company_feedback?
    }
  end

  private

  def application_event
    {
      type: :application,
      title: "Applied to #{@application.job_role.title}",
      description: "Submitted application to #{@application.company.name}",
      date: @application.applied_at || @application.created_at,
      icon: :document,
      color: :blue
    }
  end

  def interview_round_events
    @application.interview_rounds.ordered.map do |round|
      {
        type: :interview_round,
        title: round.stage_display_name,
        description: round.interviewer_display || "Interview round",
        date: round.completed_at || round.scheduled_at || round.created_at,
        icon: interview_icon(round),
        color: interview_color(round),
        status: round.result,
        round_id: round.id
      }
    end
  end

  def company_feedback_event
    feedback = @application.company_feedback
    {
      type: :company_feedback,
      title: feedback.rejection? ? "Received Rejection" : "Received Feedback",
      description: feedback.summary.truncate(100),
      date: feedback.received_at || feedback.created_at,
      icon: :chat,
      color: feedback.rejection? ? :red : :green,
      feedback_id: feedback.id
    }
  end

  def email_events
    @application.synced_emails.chronological.map do |email|
      {
        type: :email,
        title: email_event_title(email),
        description: email.short_subject(80),
        date: email.email_date || email.created_at,
        icon: email_icon(email),
        color: email_color(email),
        email_id: email.id,
        email_type: email.email_type,
        from: email.sender_display,
        snippet: email.snippet&.truncate(150),
        expandable: true
      }
    end
  end

  def email_event_title(email)
    case email.email_type
    when "interview_invite"
      "Interview Invitation"
    when "scheduling"
      "Scheduling Request"
    when "application_confirmation"
      "Application Confirmed"
    when "rejection"
      "Application Update"
    when "offer"
      "Offer Received"
    when "assessment"
      "Assessment Request"
    when "follow_up"
      "Follow Up"
    when "thank_you"
      "Thank You Note"
    else
      "Email from #{email.sender_display}"
    end
  end

  def email_icon(email)
    case email.email_type
    when "interview_invite", "scheduling"
      :calendar
    when "application_confirmation"
      :check_circle
    when "rejection"
      :x_circle
    when "offer"
      :gift
    when "assessment"
      :clipboard
    when "follow_up", "thank_you"
      :mail
    else
      :mail
    end
  end

  def email_color(email)
    case email.email_type
    when "interview_invite", "scheduling"
      :blue
    when "application_confirmation"
      :purple
    when "rejection"
      :red
    when "offer"
      :green
    when "assessment"
      :yellow
    else
      :gray
    end
  end

  def interview_icon(round)
    case round.stage.to_sym
    when :screening then :phone
    when :technical then :code
    when :hiring_manager then :user
    when :culture_fit then :users
    else :calendar
    end
  end

  def interview_color(round)
    case round.result.to_sym
    when :passed then :green
    when :failed then :red
    when :waitlisted then :yellow
    else :gray
    end
  end

  def days_since_application
    return 0 unless @application.applied_at

    (Time.current.to_date - @application.applied_at.to_date).to_i
  end
end
