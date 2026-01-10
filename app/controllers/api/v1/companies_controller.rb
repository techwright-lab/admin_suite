# frozen_string_literal: true

# API controller for companies search and creation
class Api::V1::CompaniesController < Api::V1::BaseController
  # GET /api/v1/companies
  # Search companies
  def index
    @companies = Company.enabled.alphabetical

    if params[:q].present?
      @companies = @companies.where("name ILIKE ?", "%#{params[:q]}%")
    end

    @companies = @companies.limit(params[:limit] || 50)

    render json: {
      companies: @companies.map { |company| company_json(company) },
      total: @companies.size
    }
  end

  # POST /api/v1/companies
  # Creates a new company (user-created)
  def create
    @company = Company.new(company_params)

    if @company.save
      render json: { success: true, company: company_json(@company) }, status: :created
    else
      render json: { success: false, errors: @company.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Strong parameters for company creation
  # @return [ActionController::Parameters]
  def company_params
    params.require(:company).permit(:name, :website, :about)
  end

  # Serializes company for JSON response
  # @param company [Company]
  # @return [Hash]
  def company_json(company)
    {
      id: company.id,
      name: company.name,
      website: company.website,
      logo_url: company.logo_url
    }
  end
end
