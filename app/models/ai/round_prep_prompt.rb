# frozen_string_literal: true

module Ai
  # Prompt template for generating round-specific interview preparation
  #
  # Used by InterviewRoundPrep::GenerateService to generate tailored prep content
  # for specific interview rounds based on round type, company patterns, and user history.
  #
  # Variables:
  # - {{round_context}} - JSON with round details (type, stage, duration, interviewer)
  # - {{job_context}} - JSON with job/company information
  # - {{candidate_profile}} - JSON with candidate background and skills
  # - {{historical_performance}} - JSON with user's performance on similar rounds
  # - {{company_patterns}} - JSON with company-specific interview patterns
  #
  class RoundPrepPrompt < LlmPrompt
    # Default prompt template for round prep generation
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Generate focused interview preparation for a specific interview round.

        INTERVIEW ROUND:
        {{round_context}}

        JOB CONTEXT:
        {{job_context}}

        CANDIDATE PROFILE:
        {{candidate_profile}}

        CANDIDATE'S HISTORICAL PERFORMANCE ON SIMILAR ROUNDS:
        {{historical_performance}}

        COMPANY INTERVIEW PATTERNS:
        {{company_patterns}}

        Generate a comprehensive prep guide as a JSON object with this structure:

        {
          "round_summary": {
            "type": "The round type slug (e.g., 'coding', 'system_design', 'behavioral')",
            "type_name": "Human-readable round type name",
            "company": "Company name",
            "typical_duration": "Expected duration (e.g., '45-60 min')",
            "format_hints": ["Array of format hints based on round type and company patterns"]
          },
          "expected_questions": [
            {
              "category": "Question category or theme",
              "example": "Example question or topic",
              "your_preparation": "Personalized prep advice based on candidate's background",
              "difficulty": "easy/medium/hard"
            }
          ],
          "your_history": {
            "same_type_rounds": "Number of similar rounds completed",
            "pass_rate": "Pass rate percentage or null",
            "strengths": ["Identified strengths from historical performance"],
            "areas_to_watch": ["Areas that need attention based on past feedback"]
          },
          "company_patterns": {
            "typical_focus": ["Areas this company typically focuses on"],
            "interview_style": "Description of interview style",
            "success_factors": ["Factors that correlate with success at this company"]
          },
          "answer_strategies": [
            {
              "strategy": "Strategy name",
              "description": "How to apply this strategy",
              "example_application": "Concrete example for this interview"
            }
          ],
          "preparation_checklist": [
            "Specific, actionable preparation items for this round"
          ],
          "tips": [
            "Quick tips specific to this round type and company"
          ]
        }

        Guidelines:
        - Tailor everything to the specific round type and candidate's background
        - Reference the candidate's actual skills and experience where relevant
        - Use historical performance data to personalize strengths and areas to watch
        - Incorporate company-specific patterns into format hints and focus areas
        - Keep preparation checklist items specific and actionable
        - Provide 3-5 expected questions with personalized prep advice
        - Provide 2-3 answer strategies relevant to this round type
        - Keep tips concise and immediately actionable (5-7 tips max)
        - If historical data is limited, focus on general best practices for the round type

        Respond ONLY with the JSON object, no additional text or markdown.
      PROMPT
    end

    # Default system prompt for round prep generation
    #
    # @return [String]
    def self.default_system_prompt
      <<~PROMPT
        You are an expert interview coach helping candidates prepare for specific interview rounds.
        Your goal is to provide personalized, actionable preparation guidance that:

        - Leverages the candidate's specific background and experience
        - Addresses their known strengths and areas for improvement
        - Incorporates patterns specific to the target company
        - Provides concrete, actionable preparation steps
        - Is tailored to the specific round type (coding, system design, behavioral, etc.)

        Rules:
        - Return ONLY valid JSON, no markdown or commentary
        - Be specific and personalized - avoid generic advice
        - Focus on what the candidate can do in the time before the interview
        - Reference actual skills and experience from the candidate profile
        - If company data is limited, extrapolate from general industry patterns
        - Keep advice practical and confidence-building
      PROMPT
    end

    # Returns the expected variables for this prompt type
    #
    # @return [Hash] Variable definitions
    def self.default_variables
      {
        "round_context" => {
          "required" => true,
          "description" => "JSON with interview round details (type, stage, duration, interviewer)"
        },
        "job_context" => {
          "required" => true,
          "description" => "JSON with job and company information"
        },
        "candidate_profile" => {
          "required" => true,
          "description" => "JSON with candidate background, skills, and experience"
        },
        "historical_performance" => {
          "required" => false,
          "description" => "JSON with candidate's historical performance on similar rounds"
        },
        "company_patterns" => {
          "required" => false,
          "description" => "JSON with company-specific interview patterns"
        }
      }
    end
  end
end
