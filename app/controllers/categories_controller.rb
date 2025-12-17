# frozen_string_literal: true

# Controller for category autocomplete + JSON create.
# Used by the shared autocomplete component.
class CategoriesController < ApplicationController
  # GET /categories
  def index
    @categories = Category.enabled.alphabetical
    @categories = @categories.for_kind(params[:kind]) if params[:kind].present?

    if params[:q].present?
      @categories = @categories.where("name ILIKE ?", "%#{params[:q]}%")
    end

    @categories = @categories.limit(50)

    respond_to do |format|
      format.html
      format.json { render json: @categories }
    end
  end

  # GET /categories/autocomplete
  def autocomplete
    query = params[:q].to_s.strip
    kind = params[:kind].presence

    categories = Category.enabled.alphabetical
    categories = categories.for_kind(kind) if kind

    categories = if query.present?
      categories.where("name ILIKE ?", "%#{query}%").limit(10)
    else
      categories.limit(10)
    end

    render json: categories.map { |c| { id: c.id, name: c.name, category: c.kind } }
  end

  # POST /categories
  def create
    return head :not_acceptable unless request.format.json?

    name = (params[:name] || params.dig(:category, :name))&.strip
    kind = (params[:kind] || params.dig(:category, :kind))&.to_s

    return render json: { errors: [ "Name is required" ] }, status: :unprocessable_entity if name.blank?
    return render json: { errors: [ "Kind is required" ] }, status: :unprocessable_entity if kind.blank?
    return render json: { errors: [ "Kind is invalid" ] }, status: :unprocessable_entity unless Category.kinds.key?(kind)

    category = Category.where("LOWER(name) = ? AND kind = ?", name.downcase, Category.kinds[kind]).first

    if category.nil?
      category = Category.new(name: name, kind: kind)
      if category.save
        render json: { id: category.id, name: category.name }, status: :created
      else
        render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
      end
    else
      category.update!(disabled_at: nil) if category.disabled?
      render json: { id: category.id, name: category.name }, status: :ok
    end
  end
end
