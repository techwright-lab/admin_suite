# frozen_string_literal: true

module Admin
  # Controller for managing skill tags in the admin panel
  #
  # Provides full CRUD for skill tags with usage statistics
  class SkillTagsController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 30

    before_action :set_skill_tag, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/skill_tags
    #
    # Lists skill tags with filtering and search
    def index
      @pagy, @skill_tags = paginate(filtered_skill_tags)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/skill_tags/:id
    #
    # Shows skill tag details with usage statistics
    def show
      @interview_applications = @skill_tag.interview_applications.recent.limit(10)
      @usage_count = @skill_tag.interview_applications.count
    end

    # GET /admin/skill_tags/new
    def new
      @skill_tag = SkillTag.new
    end

    # POST /admin/skill_tags
    def create
      @skill_tag = SkillTag.new(skill_tag_params)

      if @skill_tag.save
        redirect_to admin_skill_tag_path(@skill_tag), notice: "Skill tag created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/skill_tags/:id/edit
    def edit
    end

    # PATCH/PUT /admin/skill_tags/:id
    def update
      if @skill_tag.update(skill_tag_params)
        redirect_to admin_skill_tag_path(@skill_tag), notice: "Skill tag updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/skill_tags/:id
    def destroy
      @skill_tag.destroy
      redirect_to admin_skill_tags_path, notice: "Skill tag deleted.", status: :see_other
    end

    private

    # Sets the skill tag from params
    #
    # @return [void]
    def set_skill_tag
      @skill_tag = SkillTag.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_skill_tags_path, alert: "Skill tag not found."
    end

    # Returns filtered skill tags based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_skill_tags
      skill_tags = SkillTag.all

      # Filter by category
      if params[:category].present?
        skill_tags = skill_tags.where(category: params[:category])
      end

      # Search by name or category
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        skill_tags = skill_tags.where("name ILIKE :q OR category ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "name"
        skill_tags = skill_tags.order(:name)
      when "category"
        skill_tags = skill_tags.order(:category, :name)
      when "popular"
        skill_tags = skill_tags.popular
      when "recent"
        skill_tags = skill_tags.order(created_at: :desc)
      else
        skill_tags = skill_tags.order(:name)
      end

      skill_tags
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      base = SkillTag.all

      {
        total: base.count,
        with_category: base.where.not(category: [ nil, "" ]).count,
        with_usage: base.joins(:interview_applications).distinct.count,
        unused: base.left_joins(:interview_applications).where(interview_applications: { id: nil }).count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :category, :sort, :page)
    end

    # Strong params for skill tag
    #
    # @return [ActionController::Parameters] Permitted params
    def skill_tag_params
      params.require(:skill_tag).permit(:name, :category)
    end
  end
end
