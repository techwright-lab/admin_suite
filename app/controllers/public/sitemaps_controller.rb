# frozen_string_literal: true

module Public
  # Controller for generating a basic sitemap.xml.
  class SitemapsController < BaseController
    # GET /sitemap.xml
    def show
      @posts = BlogPost.published_publicly.select(:slug, :updated_at)
      @tags = ActsAsTaggableOn::Tag.joins(:taggings)
                                   .where(taggings: { taggable_type: "BlogPost" })
                                   .distinct
                                   .pluck(:name)
      respond_to do |format|
        format.xml
      end
    end
  end
end
