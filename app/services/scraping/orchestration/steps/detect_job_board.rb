# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class DetectJobBoard < BaseStep
        def call(context)
          detector = Scraping::JobBoardDetectorService.new(context.job_listing.url)
          context.detector = detector
          context.board_type = detector.detect
          context.company_slug = detector.company_slug
          context.job_id = detector.job_id

          context.event_recorder.record_simple(
            :job_board_detection,
            status: :success,
            input: { url: context.job_listing.url },
            output: {
              board_type: context.board_type,
              company_slug: context.company_slug,
              job_id: context.job_id,
              api_supported: detector.api_supported?
            }
          )

          continue
        end
      end
    end
  end
end
