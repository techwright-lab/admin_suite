# frozen_string_literal: true

# Helper methods for interview application views
#
# Provides consistent styling classes for badges, status indicators,
# and other UI elements across all interview application views.
module InterviewApplicationsHelper
  # Event type icons (SVG paths)
  EVENT_ICONS = {
    applied: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
    interview: "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z",
    interview_scheduled: "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z",
    interview_completed: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z",
    feedback: "M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z",
    feedback_received: "M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z",
    email: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
    offer: "M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    rejection: "M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z",
    rejected: "M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z",
    status_change: "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15",
    default: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
  }.freeze

  # Returns styling data for timeline events
  #
  # @param event_type [String, Symbol] The event type
  # @return [Hash] Hash containing :icon and :classes for various elements
  def timeline_event_styling(event_type)
    type = event_type.to_s.to_sym
    {
      icon: EVENT_ICONS[type] || EVENT_ICONS[:default],
      classes: timeline_event_classes(type)
    }
  end

  # Returns Tailwind classes for pipeline stage badges
  #
  # @param stage [String, Symbol] The pipeline stage
  # @return [String] Tailwind CSS classes
  def pipeline_stage_badge_classes(stage)
    case stage&.to_sym
    when :applied
      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    when :screening
      "bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400"
    when :interviewing
      "bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400"
    when :offer
      "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
    when :closed
      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    else
      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    end
  end

  # Returns Tailwind classes for application status badges
  #
  # @param status [String, Symbol, nil] The application status
  # @return [String] Tailwind CSS classes
  def application_status_badge_classes(status)
    case status&.to_sym
    when :active
      "bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400"
    when :accepted
      "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
    when :rejected
      "bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400"
    when :archived
      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    else
      "bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400"
    end
  end

  # Returns styling data for match score display
  #
  # Used in prep_snapshot to style the match score card based on
  # the fit assessment score.
  #
  # @param score [Integer, nil] The fit assessment score (0-100)
  # @return [Hash] Hash containing :label, :color, and CSS class mappings
  def match_score_styling(score)
    label, color = match_score_label_and_color(score)

    {
      label: label,
      color: color,
      classes: match_score_classes_for_color(color)
    }
  end

  # Returns just the label and color for a match score
  #
  # @param score [Integer, nil] The fit assessment score (0-100)
  # @return [Array<String, String>] [label, color]
  def match_score_label_and_color(score)
    if score.nil?
      [ "Not assessed", "slate" ]
    elsif score >= 80
      [ "Strong match", "emerald" ]
    elsif score >= 50
      [ "Partial match", "amber" ]
    else
      [ "Stretch role", "rose" ]
    end
  end

  private

  # Returns CSS class mappings for a timeline event type
  #
  # All classes are explicitly written out to ensure Tailwind
  # can detect them at build time (no dynamic string interpolation).
  #
  # @param event_type [Symbol] The event type
  # @return [Hash] CSS class mappings for various elements
  def timeline_event_classes(event_type)
    case event_type
    when :applied
      {
        dot_bg: "bg-blue-100 dark:bg-blue-900/40",
        dot_border: "border-blue-500",
        accent: "bg-blue-500",
        icon_bg: "bg-blue-100 dark:bg-blue-900/30",
        icon_text: "text-blue-600 dark:text-blue-400",
        badge_bg: "bg-blue-100 dark:bg-blue-900/30",
        badge_text: "text-blue-700 dark:text-blue-300"
      }
    when :interview, :interview_scheduled
      {
        dot_bg: "bg-violet-100 dark:bg-violet-900/40",
        dot_border: "border-violet-500",
        accent: "bg-violet-500",
        icon_bg: "bg-violet-100 dark:bg-violet-900/30",
        icon_text: "text-violet-600 dark:text-violet-400",
        badge_bg: "bg-violet-100 dark:bg-violet-900/30",
        badge_text: "text-violet-700 dark:text-violet-300"
      }
    when :interview_completed
      {
        dot_bg: "bg-emerald-100 dark:bg-emerald-900/40",
        dot_border: "border-emerald-500",
        accent: "bg-emerald-500",
        icon_bg: "bg-emerald-100 dark:bg-emerald-900/30",
        icon_text: "text-emerald-600 dark:text-emerald-400",
        badge_bg: "bg-emerald-100 dark:bg-emerald-900/30",
        badge_text: "text-emerald-700 dark:text-emerald-300"
      }
    when :feedback, :feedback_received
      {
        dot_bg: "bg-amber-100 dark:bg-amber-900/40",
        dot_border: "border-amber-500",
        accent: "bg-amber-500",
        icon_bg: "bg-amber-100 dark:bg-amber-900/30",
        icon_text: "text-amber-600 dark:text-amber-400",
        badge_bg: "bg-amber-100 dark:bg-amber-900/30",
        badge_text: "text-amber-700 dark:text-amber-300"
      }
    when :email
      {
        dot_bg: "bg-cyan-100 dark:bg-cyan-900/40",
        dot_border: "border-cyan-500",
        accent: "bg-cyan-500",
        icon_bg: "bg-cyan-100 dark:bg-cyan-900/30",
        icon_text: "text-cyan-600 dark:text-cyan-400",
        badge_bg: "bg-cyan-100 dark:bg-cyan-900/30",
        badge_text: "text-cyan-700 dark:text-cyan-300"
      }
    when :offer
      {
        dot_bg: "bg-emerald-100 dark:bg-emerald-900/40",
        dot_border: "border-emerald-500",
        accent: "bg-emerald-500",
        icon_bg: "bg-emerald-100 dark:bg-emerald-900/30",
        icon_text: "text-emerald-600 dark:text-emerald-400",
        badge_bg: "bg-emerald-100 dark:bg-emerald-900/30",
        badge_text: "text-emerald-700 dark:text-emerald-300"
      }
    when :rejection, :rejected
      {
        dot_bg: "bg-rose-100 dark:bg-rose-900/40",
        dot_border: "border-rose-500",
        accent: "bg-rose-500",
        icon_bg: "bg-rose-100 dark:bg-rose-900/30",
        icon_text: "text-rose-600 dark:text-rose-400",
        badge_bg: "bg-rose-100 dark:bg-rose-900/30",
        badge_text: "text-rose-700 dark:text-rose-300"
      }
    when :status_change
      {
        dot_bg: "bg-indigo-100 dark:bg-indigo-900/40",
        dot_border: "border-indigo-500",
        accent: "bg-indigo-500",
        icon_bg: "bg-indigo-100 dark:bg-indigo-900/30",
        icon_text: "text-indigo-600 dark:text-indigo-400",
        badge_bg: "bg-indigo-100 dark:bg-indigo-900/30",
        badge_text: "text-indigo-700 dark:text-indigo-300"
      }
    else # gray/default
      {
        dot_bg: "bg-gray-100 dark:bg-gray-700",
        dot_border: "border-gray-400 dark:border-gray-500",
        accent: "bg-gray-400 dark:bg-gray-500",
        icon_bg: "bg-gray-100 dark:bg-gray-700",
        icon_text: "text-gray-600 dark:text-gray-400",
        badge_bg: "bg-gray-100 dark:bg-gray-700",
        badge_text: "text-gray-700 dark:text-gray-300"
      }
    end
  end

  # Returns CSS class mappings for a given match color
  #
  # All classes are explicitly written out to ensure Tailwind
  # can detect them at build time (no dynamic string interpolation).
  #
  # @param color [String] The color name (emerald, amber, rose, slate)
  # @return [Hash] CSS class mappings for various elements
  def match_score_classes_for_color(color)
    case color
    when "emerald"
      {
        gradient: "from-emerald-100 dark:from-emerald-900/20",
        icon_bg: "bg-emerald-100 dark:bg-emerald-500/20",
        icon_text: "text-emerald-600 dark:text-emerald-300",
        badge_bg: "bg-emerald-100 dark:bg-emerald-900/30",
        badge_text: "text-emerald-700 dark:text-emerald-300",
        dot: "bg-emerald-500"
      }
    when "amber"
      {
        gradient: "from-amber-100 dark:from-amber-900/20",
        icon_bg: "bg-amber-100 dark:bg-amber-500/20",
        icon_text: "text-amber-600 dark:text-amber-300",
        badge_bg: "bg-amber-100 dark:bg-amber-900/30",
        badge_text: "text-amber-700 dark:text-amber-300",
        dot: "bg-amber-500"
      }
    when "rose"
      {
        gradient: "from-rose-100 dark:from-rose-900/20",
        icon_bg: "bg-rose-100 dark:bg-rose-500/20",
        icon_text: "text-rose-600 dark:text-rose-300",
        badge_bg: "bg-rose-100 dark:bg-rose-900/30",
        badge_text: "text-rose-700 dark:text-rose-300",
        dot: "bg-rose-500"
      }
    else # slate (Not assessed)
      {
        gradient: "from-slate-200 dark:from-slate-600/20",
        icon_bg: "bg-slate-200 dark:bg-slate-500/30",
        icon_text: "text-slate-600 dark:text-slate-300",
        badge_bg: "bg-slate-200 dark:bg-slate-600/30",
        badge_text: "text-slate-700 dark:text-slate-300",
        dot: "bg-slate-400 dark:bg-slate-400"
      }
    end
  end
end
