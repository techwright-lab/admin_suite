# frozen_string_literal: true

module Public
  # Controller for public tag pages (blog posts filtered by a tag).
  class BlogTagsController < BaseController
    # GET /blog/tags/:tag
    def show
      @tag = params[:tag].to_s
      @posts = BlogPost.published_publicly.tagged_with(@tag).recent_first

      redirect_to blog_index_path, alert: "Tag not found." if @posts.blank?

      set_meta_tags(
        title: "Tag: #{@tag}",
        description: "Posts tagged with #{@tag} on the Gleania blog.",
        canonical: blog_tag_url(@tag),
        og: { type: "website", url: blog_tag_url(@tag) }
      )
    end
  end
end


