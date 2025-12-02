class Avo::Resources::ScrapingAttempt < Avo::BaseResource
  self.includes = [ :job_listing ]

  self.search = {
    query: -> { query.ransack(url_cont: params[:q], domain_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id

    # Status
    field :status, as: :badge do
      case record.status.to_sym
      when :completed then { label: "Completed", color: :success }
      when :pending then { label: "Pending", color: :info }
      when :fetching then { label: "Fetching", color: :info }
      when :extracting then { label: "Extracting", color: :info }
      when :failed then { label: "Failed", color: :danger }
      when :retrying then { label: "Retrying", color: :warning }
      when :dead_letter then { label: "Needs Review", color: :warning }
      when :manual then { label: "Manual", color: :neutral }
      else { label: record.status.to_s.titleize, color: :neutral }
      end
    end

    # Basic Information
    field :job_listing, as: :belongs_to
    field :url, as: :text
    field :domain, as: :text

    # Extraction Details
    field :extraction_method, as: :select, enum: [ "api", "ai" ]
    field :provider, as: :text
    field :confidence_score, as: :number, format: "%{value}%", computed: true do
      (record.confidence_score || 0) * 100
    end

    # Performance Metrics
    field :http_status, as: :number
    field :duration_seconds, as: :text, computed: true do
      record.formatted_duration
    end
    field :retry_count, as: :number

    # Error Information
    field :error_message, as: :textarea# , only_on: [ :show ], hide_on: :create

    # Metadata
    field :request_metadata, as: :code, language: "json", only_on: [ :show ]
    field :response_metadata, as: :code, language: "json", only_on: [ :show ]

    # Domain Success Rate (computed field)
    field :domain_success_rate, as: :text, computed: true, only_on: [ :show ] do
      rate = ScrapingAttempt.success_rate_for_domain(record.domain, 7)
      "#{rate}% (last 7 days)"
    end

    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter :status_filter, StatusFilter
    filter :domain_filter, DomainFilter
    filter :needs_review_filter, NeedsReviewFilter
  end

  def actions
    action Avo::Actions::RetryExtraction
    action Avo::Actions::MarkAsManual
  end

  # Status filter
  class StatusFilter < Avo::Filters::SelectFilter
    self.name = "Status"

    def apply(request, query, value)
      query.where(status: value)
    end

    def options
      ScrapingAttempt::STATUSES.map { |s| [ s.to_s.titleize, s ] }
    end
  end

  # Domain filter
  class DomainFilter < Avo::Filters::SelectFilter
    self.name = "Domain"

    def apply(request, query, value)
      query.where(domain: value)
    end

    def options
      ScrapingAttempt.distinct.pluck(:domain).compact.map { |d| [ d, d ] }
    end
  end

  # Needs review filter
  class NeedsReviewFilter < Avo::Filters::BooleanFilter
    self.name = "Needs Review"

    def apply(request, query, value)
      return query unless value

      query.where(status: [ :dead_letter, :failed ])
    end
  end
end
