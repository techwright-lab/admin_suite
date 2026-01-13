# frozen_string_literal: true

module Public
  # Controller for public tag pages (blog posts filtered by a tag).
  class BlogTagsController < BaseController
    # GET /blog/tags/:tag
    def show
      tag_param = params[:tag].to_s
      # Find tag by slug (parameterized) or exact name
      @tag_record = ActsAsTaggableOn::Tag.find_by("LOWER(name) = ?", tag_param.tr("-", " ").downcase)
      @tag_record ||= ActsAsTaggableOn::Tag.find_by(name: tag_param)

      if @tag_record.nil?
        redirect_to blog_index_path, alert: "Tag not found."
        return
      end

      @tag = @tag_record.name
      @posts = BlogPost.published_publicly.tagged_with(@tag).recent_first

      if @posts.blank?
        redirect_to blog_index_path, alert: "No posts found for this tag."
        return
      end

      # Redirect to canonical slug URL if accessed with spaces or wrong case
      canonical_slug = @tag.parameterize
      if tag_param != canonical_slug
        redirect_to blog_tag_path(canonical_slug), status: :moved_permanently
        return
      end

      set_meta_tags(
        title: "Tag: #{@tag}",
        description: "Posts tagged with #{@tag} on the Gleania blog.",
        canonical: blog_tag_url(canonical_slug),
        og: { type: "website", url: blog_tag_url(canonical_slug) }
      )
    end
  end
end
