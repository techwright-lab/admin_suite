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

    before_action :set_skill_tag, only: [ :show, :edit, :update, :destroy, :disable, :enable, :merge, :merge_into ]

    # GET /admin/skill_tags
    #
    # Lists skill tags with filtering and search
    def index
      @pagy, @skill_tags = paginate(filtered_skill_tags)
      @stats = calculate_stats
      @filters = filter_params

      @selected_category = Category.find_by(id: params[:category_id]) if params[:category_id].present?
    end

    # GET /admin/skill_tags/:id
    #
    # Shows skill tag details with usage statistics
    def show
      @interview_applications = @skill_tag.interview_applications.recent.limit(10)
      @usage_count = @skill_tag.interview_applications.count
      @duplicate_suggestions = Dedup::FindSkillTagDuplicatesService.new(skill_tag: @skill_tag).run
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

    # POST /admin/skill_tags/:id/disable
    def disable
      @skill_tag.disable! unless @skill_tag.disabled?
      redirect_back fallback_location: admin_skill_tag_path(@skill_tag), notice: "Skill tag disabled."
    end

    # POST /admin/skill_tags/:id/enable
    def enable
      @skill_tag.enable! if @skill_tag.disabled?
      redirect_back fallback_location: admin_skill_tag_path(@skill_tag), notice: "Skill tag enabled."
    end

    # GET /admin/skill_tags/:id/merge
    def merge
      @selected_target_skill_tag = SkillTag.find_by(id: params[:target_skill_tag_id]) if params[:target_skill_tag_id].present?
    end

    # POST /admin/skill_tags/:id/merge_into
    def merge_into
      target = SkillTag.find(params[:target_skill_tag_id])

      Dedup::MergeSkillTagService.new(source_skill_tag: @skill_tag, target_skill_tag: target).run

      redirect_to admin_skill_tag_path(target), notice: "Skill tag merged into #{target.name}."
    rescue ActiveRecord::RecordNotFound
      redirect_back fallback_location: merge_admin_skill_tag_path(@skill_tag), alert: "Target skill tag not found."
    rescue ArgumentError => e
      redirect_back fallback_location: merge_admin_skill_tag_path(@skill_tag), alert: e.message
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
      if params[:category_id].present?
        skill_tags = skill_tags.where(category_id: params[:category_id])
      end

      # Search by name or category
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        skill_tags = skill_tags.left_joins(:category).where("skill_tags.name ILIKE :q OR categories.name ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "name"
        skill_tags = skill_tags.order(:name)
      when "category"
        skill_tags = skill_tags.left_joins(:category).order(Arel.sql("categories.name NULLS LAST"), :name)
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
        with_category: base.where.not(category_id: nil).count,
        with_usage: base.joins(:interview_applications).distinct.count,
        unused: base.left_joins(:interview_applications).where(interview_applications: { id: nil }).count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :category_id, :sort, :page)
    end

    # Strong params for skill tag
    #
    # @return [ActionController::Parameters] Permitted params
    def skill_tag_params
      params.require(:skill_tag).permit(:name, :category_id)
    end
  end
end
