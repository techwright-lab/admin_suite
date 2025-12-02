# frozen_string_literal: true

module Admin
  # Controller for viewing individual scraping event details
  #
  # Provides a detailed view of a single pipeline step with full
  # input/output payloads for debugging.
  class ScrapingEventsController < BaseController
    before_action :set_scraping_event, only: [ :show ]

    # GET /admin/scraping_events/:id
    def show
      @attempt = @event.scraping_attempt
      @prev_event = @attempt.scraping_events.where("step_order < ?", @event.step_order).order(step_order: :desc).first
      @next_event = @attempt.scraping_events.where("step_order > ?", @event.step_order).order(step_order: :asc).first
    end

    private

    # Sets the scraping event from params
    def set_scraping_event
      @event = ScrapingEvent.includes(:scraping_attempt, :job_listing).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_scraping_attempts_path, alert: "Scraping event not found"
    end
  end
end

