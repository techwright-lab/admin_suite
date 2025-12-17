# frozen_string_literal: true

module Public
  # Controller for generating a basic sitemap.xml.
  class SitemapsController < BaseController
    # GET /sitemap.xml
    def show
      @posts = BlogPost.published_publicly.select(:slug, :updated_at)
      respond_to do |format|
        format.xml
      end
    end
  end
end


