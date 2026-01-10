# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: get interview prep artifacts for a specific application.
    # Returns existing prep artifacts (match analysis, focus areas, strength positioning, question framing).
    class GetInterviewPrepTool < BaseTool
      def call(args:, tool_execution:)
        application_id = (args["application_id"] || args[:application_id]).to_i

        if application_id.zero?
          return { success: false, error: "application_id is required" }
        end

        application = user.interview_applications.find_by(id: application_id)

        if application.nil?
          return { success: false, error: "Interview application not found" }
        end

        artifacts = application.interview_prep_artifacts.includes(:llm_api_log)

        {
          success: true,
          data: {
            application: {
              id: application.id,
              company: application.display_company&.name,
              role: application.display_job_role&.title,
              status: application.status,
              pipeline_stage: application.pipeline_stage
            },
            prep_artifacts: format_artifacts(artifacts),
            has_all_artifacts: artifacts.computed.count == InterviewPrepArtifact::KINDS.size
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def format_artifacts(artifacts)
        result = {}

        InterviewPrepArtifact::KINDS.each do |kind|
          artifact = artifacts.find { |a| a.kind == kind.to_s }

          if artifact.nil?
            result[kind] = { status: "not_generated" }
          else
            result[kind] = format_artifact(artifact)
          end
        end

        result
      end

      def format_artifact(artifact)
        base = {
          status: artifact.status,
          computed_at: artifact.computed_at&.iso8601
        }

        if artifact.computed?
          base[:content] = format_content(artifact.kind, artifact.content)
        elsif artifact.failed?
          base[:error] = artifact.error_message
        end

        base
      end

      def format_content(kind, content)
        return {} unless content.is_a?(Hash)

        case kind.to_sym
        when :match_analysis
          {
            match_label: content["match_label"],
            strong_in: content["strong_in"],
            partial_in: content["partial_in"],
            missing_or_risky: content["missing_or_risky"],
            notes: content["notes"]
          }.compact
        when :focus_areas
          {
            areas: content["areas"],
            notes: content["notes"]
          }.compact
        when :strength_positioning
          {
            strengths: content["strengths"],
            positioning_tips: content["positioning_tips"],
            notes: content["notes"]
          }.compact
        when :question_framing
          {
            questions: content["questions"],
            frameworks: content["frameworks"],
            notes: content["notes"]
          }.compact
        else
          content
        end
      end
    end
  end
end
