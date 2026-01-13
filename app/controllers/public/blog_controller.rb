# frozen_string_literal: true

module Public
  # Controller for the public blog.
  class BlogController < BaseController
    # GET /blog
    def index
      @posts = BlogPost.published_publicly.recent_first
      @tag_cloud = ActsAsTaggableOn::Tag
        .joins(:taggings)
        .where(taggings: { taggable_type: "BlogPost", context: "tags" })
        .group("tags.id")
        .select("tags.*, COUNT(taggings.id) AS usage_count")
        .order("usage_count DESC, tags.name ASC")
        .limit(30)

      set_meta_tags(
        title: "Blog",
        description: "Product thinking, interview strategy, and job-search workflows from Gleania.",
        canonical: blog_index_url,
        og: {
          type: "website",
          url: blog_index_url,
          title: "The Gleania Blog",
          description: "Product thinking, interview strategy, and job-search workflows from Gleania.",
          site_name: "Gleania"
        },
        twitter: {
          card: "summary",
          site: "@GleaniaApp",
          title: "The Gleania Blog",
          description: "Product thinking, interview strategy, and job-search workflows from Gleania."
        }
      )
    end

    # GET /blog/:slug
    def show
      @post = BlogPost.friendly.find(params[:slug])
      raise ActiveRecord::RecordNotFound unless @post.publicly_visible?

      rendered = MarkdownRenderer.new(@post.body).render
      @content_html = rendered[:html]
      @toc = rendered[:toc]
      @reading_time_minutes = rendered[:reading_time_minutes]

      og_image =
        if @post.cover_image.attached?
          if Rails.env.production?
            @post.cover_image.url
          else
            url_for(@post.cover_image_variant(size: :og))
          end
        end

      description = @post.excerpt.presence || "Read #{@post.title} on the Gleania blog."

      set_meta_tags(
        title: @post.title,
        description: description,
        canonical: blog_url(@post.slug),
        # Open Graph (used by LinkedIn, Facebook, etc.)
        og: {
          type: "article",
          url: blog_url(@post.slug),
          title: @post.title,
          description: description,
          image: og_image,
          site_name: "Gleania"
        },
        # Article-specific meta (LinkedIn reads these)
        article: {
          published_time: @post.published_at&.iso8601,
          modified_time: @post.updated_at&.iso8601,
          author: @post.author_name.presence || "Gleania Team",
          section: "Interview Tips",
          tag: @post.tag_list.to_a
        },
        # Twitter Card
        twitter: {
          card: "summary_large_image",
          site: "@GleaniaApp",
          creator: "@GleaniaApp",
          title: @post.title,
          description: description,
          image: og_image
        }
      )
    rescue ActiveRecord::RecordNotFound
      redirect_to blog_index_path, alert: "Post not found."
    end
  end
end
