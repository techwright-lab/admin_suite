# frozen_string_literal: true

# Service for analyzing interview feedback and generating AI summaries
class FeedbackAnalysisService
  # @param interview_feedback [InterviewFeedback] The interview feedback to analyze
  def initialize(interview_feedback)
    @interview_feedback = interview_feedback
  end

  # Analyzes the feedback and generates summary and tags
  # @return [Hash] Hash containing ai_summary and tags
  def analyze
    # TODO: Implement actual AI analysis using OpenAI/Anthropic API
    # For now, return placeholder data
    {
      ai_summary: generate_placeholder_summary,
      tags: extract_placeholder_tags,
      recommended_action: generate_placeholder_recommendation
    }
  end

  # Generates AI summary for the feedback
  # @return [String] Generated summary
  def generate_summary
    # TODO: Implement actual AI summary generation
    generate_placeholder_summary
  end

  # Extracts skill tags from feedback
  # @return [Array<String>] Array of extracted tags
  def extract_tags
    # TODO: Implement actual tag extraction
    extract_placeholder_tags
  end

  # Generates a recommended action
  # @return [String] Recommended action
  def generate_recommendation
    # TODO: Implement actual recommendation generation
    generate_placeholder_recommendation
  end

  private

  def generate_placeholder_summary
    strengths = @interview_feedback.went_well.present? ? "strong performance in discussed areas" : "areas to celebrate"
    improvements = @interview_feedback.to_improve.present? ? "opportunities for growth identified" : "room for development"
    
    "You showed #{strengths}. There are #{improvements}. Continue building on your strengths while addressing areas for improvement."
  end

  def extract_placeholder_tags
    # Simple keyword extraction as placeholder
    text = [
      @interview_feedback.went_well,
      @interview_feedback.to_improve,
      @interview_feedback.self_reflection
    ].compact.join(" ")

    common_skills = [
      "Communication", "System Design", "Problem Solving", 
      "Leadership", "Technical Skills", "Collaboration"
    ]

    common_skills.select { |skill| text.downcase.include?(skill.downcase) }
  end

  def generate_placeholder_recommendation
    return nil if @interview_feedback.to_improve.blank?

    "Focus on practicing the areas you identified for improvement. Consider mock interviews or study sessions targeting these specific topics."
  end
end

