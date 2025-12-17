# frozen_string_literal: true

module Admin
  # Controller for managing categories in the admin panel.
  class CategoriesController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 30

    before_action :set_category, only: [ :show, :edit, :update, :destroy, :disable, :enable, :merge, :merge_into ]

    def index
      @pagy, @categories = paginate(filtered_categories)
      @stats = calculate_stats
      @filters = filter_params

      @selected_target = Category.find_by(id: params[:target_category_id]) if params[:target_category_id].present?
    end

    def show
      @usage_count = usage_relation.count
      @recent_usage = usage_relation.order(created_at: :desc).limit(10)
      @duplicate_suggestions = Dedup::FindCategoryDuplicatesService.new(category: @category).run
    end

    def new
      @category = Category.new
    end

    def create
      @category = Category.new(category_params)

      if @category.save
        redirect_to admin_category_path(@category), notice: "Category created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to admin_category_path(@category), notice: "Category updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def disable
      @category.disable! unless @category.disabled?
      redirect_back fallback_location: admin_category_path(@category), notice: "Category disabled."
    end

    def enable
      @category.enable! if @category.disabled?
      redirect_back fallback_location: admin_category_path(@category), notice: "Category enabled."
    end

    def merge
      @selected_target_category = Category.find_by(id: params[:target_category_id]) if params[:target_category_id].present?
    end

    def merge_into
      target = Category.find(params[:target_category_id])

      Dedup::MergeCategoryService.new(source_category: @category, target_category: target).run

      redirect_to admin_category_path(target), notice: "Category merged into #{target.name}."
    rescue ActiveRecord::RecordNotFound
      redirect_back fallback_location: merge_admin_category_path(@category), alert: "Target category not found."
    rescue ArgumentError => e
      redirect_back fallback_location: merge_admin_category_path(@category), alert: e.message
    end

    def destroy
      if usage_relation.exists?
        redirect_back(
          fallback_location: admin_category_path(@category),
          alert: "Can't delete a category with usage. Disable it instead (or merge duplicates)."
        )
        return
      end

      @category.destroy
      redirect_to admin_categories_path, notice: "Category deleted.", status: :see_other
    end

    private

    def set_category
      @category = Category.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_categories_path, alert: "Category not found."
    end

    def filtered_categories
      categories = Category.all

      categories = categories.where(kind: params[:kind]) if params[:kind].present?
      categories = categories.enabled if params[:status] == "enabled"
      categories = categories.disabled if params[:status] == "disabled"

      if params[:search].present?
        categories = categories.where("name ILIKE ?", "%#{params[:search]}%")
      end

      case params[:sort]
      when "name"
        categories = categories.order(:name)
      when "kind"
        categories = categories.order(:kind, :name)
      when "recent"
        categories = categories.order(created_at: :desc)
      else
        categories = categories.order(:kind, :name)
      end

      categories
    end

    def calculate_stats
      base = Category.all

      {
        total: base.count,
        job_role: base.where(kind: :job_role).count,
        skill_tag: base.where(kind: :skill_tag).count,
        disabled: base.disabled.count
      }
    end

    def filter_params
      params.permit(:search, :kind, :status, :sort, :page)
    end

    def category_params
      params.require(:category).permit(:name, :kind)
    end

    def usage_relation
      case @category.kind.to_s
      when "job_role"
        JobRole.where(category_id: @category.id)
      when "skill_tag"
        SkillTag.where(category_id: @category.id)
      else
        JobRole.none
      end
    end
  end
end
