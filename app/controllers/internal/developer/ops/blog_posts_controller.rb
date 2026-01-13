# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class BlogPostsController < Internal::Developer::ResourcesController
        before_action :set_blog_post, only: %i[publish unpublish]

        # POST /internal/developer/ops/blog_posts/:id/publish
        def publish
          if @blog_post.update(status: :published, published_at: @blog_post.published_at || Time.current)
            redirect_to internal_developer_ops_blog_post_path(@blog_post), notice: "Blog post published successfully."
          else
            redirect_to internal_developer_ops_blog_post_path(@blog_post), alert: "Failed to publish blog post."
          end
        end

        # POST /internal/developer/ops/blog_posts/:id/unpublish
        def unpublish
          if @blog_post.update(status: :draft)
            redirect_to internal_developer_ops_blog_post_path(@blog_post), notice: "Blog post unpublished successfully."
          else
            redirect_to internal_developer_ops_blog_post_path(@blog_post), alert: "Failed to unpublish blog post."
          end
        end

        private

        def set_blog_post
          @blog_post = BlogPost.friendly.find(params[:id])
        end

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
