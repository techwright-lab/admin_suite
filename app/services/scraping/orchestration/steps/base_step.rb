# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class BaseStep < ApplicationService
        def call(_context)
          raise NotImplementedError
        end

        private

        def continue
          :continue
        end

        def stop_success
          :stop_success
        end

        def stop_failure
          :stop_failure
        end
      end
    end
  end
end
