# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class BlogPostsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::BlogPostResource
        end

        def current_portal
          :ops
        end
      end
    end
  end
end

