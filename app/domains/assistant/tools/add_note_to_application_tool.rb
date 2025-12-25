# frozen_string_literal: true

module Assistant
  module Tools
    # Write: append or replace notes on an interview application.
    class AddNoteToApplicationTool < BaseTool
      def call(args:, tool_execution:)
        application_uuid = (args["application_uuid"] || args[:application_uuid]).to_s
        note = (args["note"] || args[:note]).to_s
        mode = (args["mode"] || args[:mode] || "append").to_s

        return { success: false, error: "application_uuid is required" } if application_uuid.blank?
        return { success: false, error: "note is blank" } if note.strip.blank?

        app = user.interview_applications.find_by(uuid: application_uuid)
        return { success: false, error: "Interview application not found" } if app.nil?

        new_notes =
          if mode == "replace"
            note
          else
            existing = app.notes.to_s
            existing.blank? ? note : "#{existing}\n\n#{note}"
          end

        app.update!(notes: new_notes)

        { success: true, data: { application_uuid: app.uuid, notes_length: app.notes.to_s.length } }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
