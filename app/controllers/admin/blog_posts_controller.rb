# frozen_string_literal: true

module Admin
  # Controller for managing blog posts in the admin panel.
  class BlogPostsController < BaseController
    include Concerns::Paginatable

    PER_PAGE = 30

    before_action :set_blog_post, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/blog_posts
    def index
      @pagy, @blog_posts = paginate(filtered_blog_posts)
    end

    # GET /admin/blog_posts/:id
    def show
      rendered = MarkdownRenderer.new(@blog_post.body).render
      @content_html = rendered[:html]
    end

    # GET /admin/blog_posts/new
    def new
      @blog_post = BlogPost.new
    end

    # POST /admin/blog_posts
    def create
      @blog_post = BlogPost.new(blog_post_params)

      if @blog_post.save
        redirect_to admin_blog_post_path(@blog_post), notice: "Blog post created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/blog_posts/:id/edit
    def edit
    end

    # PATCH/PUT /admin/blog_posts/:id
    def update
      if @blog_post.update(blog_post_params)
        redirect_to admin_blog_post_path(@blog_post), notice: "Blog post updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/blog_posts/:id
    def destroy
      @blog_post.destroy
      redirect_to admin_blog_posts_path, notice: "Blog post deleted.", status: :see_other
    end

    private

    def set_blog_post
      @blog_post = BlogPost.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_blog_posts_path, alert: "Blog post not found."
    end

    def filtered_blog_posts
      scope = BlogPost.all

      scope = scope.where(status: params[:status]) if params[:status].present?
      if params[:search].present?
        q = "%#{params[:search]}%"
        scope = scope.where("title ILIKE ? OR slug ILIKE ?", q, q)
      end

      case params[:sort]
      when "title"
        scope = scope.order(:title)
      when "recent"
        scope = scope.order(created_at: :desc)
      when "published_at"
        scope = scope.order(published_at: :desc, created_at: :desc)
      else
        scope = scope.order(created_at: :desc)
      end

      scope
    end

    def blog_post_params
      params.require(:blog_post).permit(
        :title,
        :slug,
        :excerpt,
        :body,
        :status,
        :published_at,
        :author_name,
        :tag_list,
        :cover_image
      )
    end
  end
end
