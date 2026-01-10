# frozen_string_literal: true

module Assistant
  module Tools
    # Write: generate interview prep artifacts for a specific application.
    # Triggers background generation of match analysis, focus areas, strength positioning, and question framing.
    class GenerateInterviewPrepTool < BaseTool
      VALID_KINDS = InterviewPrepArtifact::KINDS.map(&:to_s).freeze

      def call(args:, tool_execution:)
        application_id = (args["application_id"] || args[:application_id]).to_i
        kinds = extract_kinds(args)

        if application_id.zero?
          return { success: false, error: "application_id is required" }
        end

        application = user.interview_applications.find_by(id: application_id)

        if application.nil?
          return { success: false, error: "Interview application not found" }
        end

        if kinds.empty?
          return { success: false, error: "At least one prep type must be specified. Valid types: #{VALID_KINDS.join(', ')}" }
        end

        # Generate artifacts synchronously (they have caching via inputs_digest)
        results = generate_artifacts(application, kinds)

        {
          success: results[:failures].zero?,
          data: {
            application: {
              id: application.id,
              company: application.display_company&.name,
              role: application.display_job_role&.title
            },
            generated: results[:generated],
            cached: results[:cached],
            failed: results[:failed_kinds],
            results: results[:details]
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def extract_kinds(args)
        # Allow specifying specific kinds or "all"
        kinds_arg = args["kinds"] || args[:kinds]

        if kinds_arg == "all" || kinds_arg.nil?
          return VALID_KINDS
        end

        Array(kinds_arg).map(&:to_s).select { |k| VALID_KINDS.include?(k) }
      end

      def generate_artifacts(application, kinds)
        generated = []
        cached = []
        failed_kinds = []
        details = {}

        kinds.each do |kind|
          service = service_for_kind(kind)
          next if service.nil?

          artifact = service.new(user: user, interview_application: application).call

          if artifact.computed?
            if artifact.saved_change_to_computed_at?
              generated << kind
              details[kind] = { status: "generated", computed_at: artifact.computed_at&.iso8601 }
            else
              cached << kind
              details[kind] = { status: "cached", computed_at: artifact.computed_at&.iso8601 }
            end
          else
            failed_kinds << kind
            details[kind] = { status: "failed", error: artifact.error_message }
          end
        rescue StandardError => e
          failed_kinds << kind
          details[kind] = { status: "failed", error: e.message }
        end

        {
          generated: generated,
          cached: cached,
          failed_kinds: failed_kinds,
          failures: failed_kinds.size,
          details: details
        }
      end

      def service_for_kind(kind)
        case kind.to_sym
        when :match_analysis
          InterviewPrep::GenerateMatchAnalysisService
        when :focus_areas
          InterviewPrep::GenerateFocusAreasService
        when :strength_positioning
          InterviewPrep::GenerateStrengthPositioningService
        when :question_framing
          InterviewPrep::GenerateQuestionFramingService
        end
      end
    end
  end
end
