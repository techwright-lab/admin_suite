# frozen_string_literal: true

# Controller for managing companies
class CompaniesController < ApplicationController
  # GET /companies
  def index
    @companies = Company.enabled.alphabetical

    if params[:q].present?
      @companies = @companies.where("name ILIKE ?", "%#{params[:q]}%")
    end

    @companies = @companies.limit(50)

    respond_to do |format|
      format.html
      format.json { render json: @companies }
    end
  end

  # GET /companies/autocomplete
  def autocomplete
    query = params[:q].to_s.strip

    @companies = if query.present?
      Company.enabled.where("name ILIKE ?", "%#{query}%")
        .alphabetical
        .limit(10)
    else
      Company.enabled.alphabetical.limit(10)
    end

    render json: @companies.map { |c| { id: c.id, name: c.name, website: c.website } }
  end

  # POST /companies
  def create
    # Handle both form params and JSON params (for auto-create)
    if request.format.json?
      # Auto-create from autocomplete - only name is required
      name = (params[:name] || params.dig(:company, :name))&.strip
      return render json: { errors: [ "Name is required" ] }, status: :unprocessable_entity if name.blank?

      # Find by case-insensitive name
      @company = Company.where("LOWER(name) = ?", name.downcase).first

      if @company.nil?
        # Create new company
        @company = Company.new(name: name)
        if @company.save
          render json: { id: @company.id, name: @company.name }, status: :created
        else
          render json: { errors: @company.errors.full_messages }, status: :unprocessable_entity
        end
      else
        # If it exists but was disabled, re-enable it
        @company.update!(disabled_at: nil) if @company.disabled?
        # Company already exists, return it
        render json: { id: @company.id, name: @company.name }, status: :ok
      end
    else
      # Regular form submission
      @company = Company.new(company_params)

      if @company.save
        respond_to do |format|
          format.html { redirect_to companies_path, notice: "Company created successfully!" }
          format.turbo_stream { flash.now[:notice] = "Company created successfully!" }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end
  end

  private

  def company_params
    params.expect(company: [ :name, :website, :about, :logo_url ])
  end
end
