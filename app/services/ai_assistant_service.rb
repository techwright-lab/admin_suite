# frozen_string_literal: true

# Service for handling AI assistant queries with context
class AiAssistantService
  # @param user [User] The user making the query
  # @param question [String] The question to answer
  def initialize(user, question)
    @user = user
    @question = question.strip.downcase
  end

  # Generates an answer based on the question
  # @return [String] The answer
  def answer
    # Route to appropriate handler based on question keywords
    case @question
    when /summarize.*interview/
      summarize_interviews
    when /thank.*you.*email/
      generate_thank_you_email
    when /prepare|preparation/
      suggest_preparation
    when /skill|improve|focus/
      suggest_skills_to_focus
    else
      default_response
    end
  end

  private

  def summarize_interviews
    interviews = @user.interviews.order(created_at: :desc).limit(3).includes(:feedback_entries)

    if interviews.empty?
      return "You haven't added any interviews yet. Start by adding your first interview to track your progress!"
    end

    summary = "Here's a summary of your last #{interviews.count} interviews:\n\n"

    interviews.each_with_index do |interview, index|
      summary += "#{index + 1}. **#{interview.company}** - #{interview.role}\n"
      summary += "   Stage: #{interview.stage.humanize}\n"

      if interview.feedback_entries.any?
        latest_feedback = interview.feedback_entries.order(created_at: :desc).first
        summary += "   Reflection: #{latest_feedback.summary_preview}\n"
      else
        summary += "   No feedback added yet\n"
      end
      summary += "\n"
    end

    summary
  end

  def generate_thank_you_email
    latest_interview = @user.interviews.order(created_at: :desc).first

    return "Add an interview first to generate a thank you email!" unless latest_interview

    <<~EMAIL
      Here's a template thank you email for your interview at #{latest_interview.company}:

      Subject: Thank you for the opportunity - #{latest_interview.role}

      Dear Hiring Team,

      Thank you for taking the time to speak with me about the #{latest_interview.role} position at #{latest_interview.company}. I enjoyed learning more about the role and the team.

      Our conversation reinforced my enthusiasm for this opportunity. I'm particularly excited about [mention specific aspect discussed].

      I'm confident that my experience and skills align well with what you're looking for, and I'm eager to contribute to your team's success.

      Please don't hesitate to reach out if you need any additional information. I look forward to hearing from you.

      Best regards,
      #{@user.display_name}
    EMAIL
  end

  def suggest_preparation
    feedback_entries = @user.feedback_entries.where.not(to_improve: nil).limit(5)

    if feedback_entries.empty?
      return "Add feedback to your interviews to get personalized preparation suggestions based on your areas of improvement!"
    end

    # Extract common improvement areas
    improvement_areas = feedback_entries.flat_map(&:tag_list).tally.sort_by { |_k, v| -v }.first(3)

    response = "Based on your feedback, here's what to focus on for your next interview:\n\n"

    if improvement_areas.any?
      response += "**Key Areas to Prepare:**\n"
      improvement_areas.each do |skill, count|
        response += "- #{skill} (mentioned #{count} times)\n"
      end
      response += "\n"
    end

    response += "**Preparation Tips:**\n"
    response += "1. Practice mock interviews focusing on your improvement areas\n"
    response += "2. Review successful examples from past interviews\n"
    response += "3. Prepare specific stories that demonstrate your skills\n"
    response += "4. Research the company culture and values\n"

    response
  end

  def suggest_skills_to_focus
    insights = ProfileInsightsService.new(@user).generate_insights
    improvements = insights[:improvements]

    if improvements.empty?
      return "Add feedback to your interviews to identify which skills to focus on improving!"
    end

    response = "Based on your interview feedback, here are skills to focus on:\n\n"

    improvements.each_with_index do |improvement, index|
      response += "#{index + 1}. **#{improvement[:name]}**\n"
      response += "   Mentioned in #{improvement[:count]} feedback entries\n\n"
    end

    response += "Consider dedicating time to practice and improve these areas through:\n"
    response += "- Online courses or tutorials\n"
    response += "- Mock interviews with peers\n"
    response += "- Personal projects that use these skills\n"

    response
  end

  def default_response
    <<~RESPONSE
      I can help you with:

      • **Summarizing interviews** - Try: "Summarize my last 3 interviews"
      • **Thank you emails** - Try: "Generate a thank you email"
      • **Interview preparation** - Try: "How should I prepare for interviews?"
      • **Skills to focus on** - Try: "What skills should I improve?"

      What would you like help with?
    RESPONSE
  end
end
