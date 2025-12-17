# frozen_string_literal: true

module Admin
  # Provides tag suggestions for the blog post tag picker.
  class BlogTagsController < BaseController
    # GET /admin/blog_tags
    def index
      q = params[:q].to_s.strip

      tags = ActsAsTaggableOn::Tag
        .where("name ILIKE ?", "%#{q}%")
        .order(:name)
        .limit(20)
        .pluck(:name)

      render json: { tags: tags }
    end
  end
end


