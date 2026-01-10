# frozen_string_literal: true

# API controller for domains search and creation
class Api::V1::DomainsController < Api::V1::BaseController
  # GET /api/v1/domains
  # Search domains
  def index
    @domains = Domain.enabled.alphabetical

    if params[:q].present?
      @domains = @domains.search(params[:q])
    end

    @domains = @domains.limit(params[:limit] || 50)

    render json: {
      domains: @domains.map { |domain| domain_json(domain) },
      total: @domains.size
    }
  end

  # POST /api/v1/domains
  # Creates a new domain (user-created)
  def create
    @domain = Domain.new(domain_params)

    if @domain.save
      render json: { success: true, domain: domain_json(@domain) }, status: :created
    else
      render json: { success: false, errors: @domain.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Strong parameters for domain creation
  # @return [ActionController::Parameters]
  def domain_params
    params.require(:domain).permit(:name, :description)
  end

  # Serializes domain for JSON response
  # @param domain [Domain]
  # @return [Hash]
  def domain_json(domain)
    {
      id: domain.id,
      name: domain.name,
      slug: domain.slug,
      description: domain.description
    }
  end
end
