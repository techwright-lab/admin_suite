# frozen_string_literal: true

# Controller for skill tag autocomplete + JSON create.
# Used by the shared autocomplete component.
class SkillTagsController < ApplicationController
  # GET /skill_tags
  def index
    @skill_tags = SkillTag.enabled.alphabetical

    if params[:q].present?
      @skill_tags = @skill_tags.where("name ILIKE ?", "%#{params[:q]}%")
    end

    @skill_tags = @skill_tags.limit(50)

    respond_to do |format|
      format.html
      format.json { render json: @skill_tags }
    end
  end

  # GET /skill_tags/autocomplete
  def autocomplete
    query = params[:q].to_s.strip

    @skill_tags = if query.present?
      SkillTag.enabled.where("name ILIKE ?", "%#{query}%")
        .alphabetical
        .limit(10)
    else
      SkillTag.enabled.alphabetical.limit(10)
    end

    render json: @skill_tags.map { |t| { id: t.id, name: t.name, category: t.category_name } }
  end

  # POST /skill_tags
  def create
    return head :not_acceptable unless request.format.json?

    name = (params[:name] || params.dig(:skill_tag, :name))&.strip
    return render json: { errors: [ "Name is required" ] }, status: :unprocessable_entity if name.blank?

    # Find by case-insensitive name
    @skill_tag = SkillTag.where("LOWER(name) = ?", name.downcase).first

    if @skill_tag.nil?
      @skill_tag = SkillTag.new(name: name)
      if @skill_tag.save
        render json: { id: @skill_tag.id, name: @skill_tag.name }, status: :created
      else
        render json: { errors: @skill_tag.errors.full_messages }, status: :unprocessable_entity
      end
    else
      @skill_tag.update!(disabled_at: nil) if @skill_tag.disabled?
      render json: { id: @skill_tag.id, name: @skill_tag.name }, status: :ok
    end
  end
end
