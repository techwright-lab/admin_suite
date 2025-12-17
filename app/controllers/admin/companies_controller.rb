# frozen_string_literal: true

module Admin
  # Controller for managing companies in the admin panel
  #
  # Provides full CRUD for companies with associations visibility
  class CompaniesController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 30

    before_action :set_company, only: [ :show, :edit, :update, :destroy, :disable, :enable, :merge, :merge_into ]

    # GET /admin/companies
    #
    # Lists companies with filtering and search
    def index
      @pagy, @companies = paginate(filtered_companies)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/companies/:id
    #
    # Shows company details with associations
    def show
      @job_listings = @company.job_listings.recent.limit(10)
      @interview_applications = @company.interview_applications.recent.limit(10)
      @current_employees = @company.users_with_current_company.limit(10)
      @users_targeting = @company.users_targeting.limit(10)
      @duplicate_suggestions = Dedup::FindCompanyDuplicatesService.new(company: @company).run
    end

    # GET /admin/companies/new
    def new
      @company = Company.new
    end

    # POST /admin/companies
    def create
      @company = Company.new(company_params)

      if @company.save
        redirect_to admin_company_path(@company), notice: "Company created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/companies/:id/edit
    def edit
    end

    # PATCH/PUT /admin/companies/:id
    def update
      if @company.update(company_params)
        redirect_to admin_company_path(@company), notice: "Company updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # POST /admin/companies/:id/disable
    def disable
      @company.disable! unless @company.disabled?
      redirect_back fallback_location: admin_company_path(@company), notice: "Company disabled."
    end

    # POST /admin/companies/:id/enable
    def enable
      @company.enable! if @company.disabled?
      redirect_back fallback_location: admin_company_path(@company), notice: "Company enabled."
    end

    # GET /admin/companies/:id/merge
    def merge
      @selected_target_company = Company.find_by(id: params[:target_company_id]) if params[:target_company_id].present?
    end

    # POST /admin/companies/:id/merge_into
    def merge_into
      target = Company.find(params[:target_company_id])

      Dedup::MergeCompanyService.new(source_company: @company, target_company: target).run

      redirect_to admin_company_path(target), notice: "Company merged into #{target.name}."
    rescue ActiveRecord::RecordNotFound
      redirect_back fallback_location: merge_admin_company_path(@company), alert: "Target company not found."
    rescue ArgumentError => e
      redirect_back fallback_location: merge_admin_company_path(@company), alert: e.message
    end

    # DELETE /admin/companies/:id
    def destroy
      if @company.job_listings.exists?
        redirect_back(
          fallback_location: admin_company_path(@company),
          alert: "Can't delete a company with job listings. Disable it instead (or merge duplicates)."
        )
        return
      end

      @company.destroy
      redirect_to admin_companies_path, notice: "Company deleted.", status: :see_other
    end

    private

    # Sets the company from params
    #
    # @return [void]
    def set_company
      @company = Company.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_companies_path, alert: "Company not found."
    end

    # Returns filtered companies based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_companies
      companies = Company.all

      # Search by name or website
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        companies = companies.where("name ILIKE :q OR website ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "name"
        companies = companies.order(:name)
      when "recent"
        companies = companies.order(created_at: :desc)
      else
        companies = companies.order(:name)
      end

      companies
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      base = Company.all

      {
        total: base.count,
        with_website: base.where.not(website: [ nil, "" ]).count,
        with_logo: base.where.not(logo_url: [ nil, "" ]).count,
        with_job_listings: base.joins(:job_listings).distinct.count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :sort, :page)
    end

    # Strong params for company
    #
    # @return [ActionController::Parameters] Permitted params
    def company_params
      params.require(:company).permit(:name, :website, :about, :logo_url)
    end
  end
end
