# frozen_string_literal: true

module Admin
  module Ai
    # Controller for managing LLM prompt templates in the admin panel
    #
    # Provides full CRUD for prompt templates with activate and duplicate actions.
    # Supports STI subclasses (JobExtractionPrompt, EmailExtractionPrompt, ResumeSkillExtractionPrompt).
    class LlmPromptsController < Admin::BaseController
      include Concerns::Paginatable
      include Concerns::Filterable
      include Concerns::StatsCalculator

      PER_PAGE = 20

      before_action :set_prompt, only: [ :show, :edit, :update, :destroy, :activate, :duplicate ]

      # GET /admin/ai/llm_prompts
      #
      # Lists prompt templates with filtering by type and status
      def index
        @pagy, @prompts = paginate(filtered_prompts)
        @stats = calculate_stats
        @filters = filter_params
      end

      # GET /admin/ai/llm_prompts/:id
      #
      # Shows prompt template details with variables
      def show
        @template_variables = @prompt.template_variables
      end

      # GET /admin/ai/llm_prompts/new
      def new
        @prompt = prompt_class.new(version: 1, active: false)
        @prompt.variables = prompt_class.respond_to?(:default_variables) ? prompt_class.default_variables : {}
      end

      # POST /admin/ai/llm_prompts
      def create
        @prompt = prompt_class.new(prompt_params)

        if @prompt.save
          redirect_to admin_ai_llm_prompt_path(@prompt), notice: "Prompt template created successfully."
        else
          render :new, status: :unprocessable_entity
        end
      end

      # GET /admin/ai/llm_prompts/:id/edit
      def edit
      end

      # PATCH/PUT /admin/ai/llm_prompts/:id
      def update
        if @prompt.update(prompt_params)
          redirect_to admin_ai_llm_prompt_path(@prompt), notice: "Prompt template updated successfully."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /admin/ai/llm_prompts/:id
      def destroy
        @prompt.destroy
        redirect_to admin_ai_llm_prompts_path, notice: "Prompt template deleted.", status: :see_other
      end

      # POST /admin/ai/llm_prompts/:id/activate
      #
      # Activates this template and deactivates all others of the same type
      def activate
        @prompt.update(active: true)
        redirect_to admin_ai_llm_prompt_path(@prompt), notice: "Template activated successfully."
      end

      # POST /admin/ai/llm_prompts/:id/duplicate
      #
      # Creates a copy of this template with incremented version
      def duplicate
        new_prompt = @prompt.duplicate

        if new_prompt.save
          redirect_to admin_ai_llm_prompt_path(new_prompt), notice: "Template duplicated successfully."
        else
          redirect_to admin_ai_llm_prompt_path(@prompt), alert: "Failed to duplicate template: #{new_prompt.errors.full_messages.join(', ')}"
        end
      end

      private

      # Sets the prompt from params
      #
      # @return [void]
      def set_prompt
        @prompt = ::Ai::LlmPrompt.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to admin_ai_llm_prompts_path, alert: "Prompt template not found."
      end

      # Returns the prompt class based on params or default
      #
      # @return [Class] The prompt class
      def prompt_class
        case params[:prompt_type] || params.dig(:llm_prompt, :type)
        when "Ai::JobExtractionPrompt", "job_extraction"
          ::Ai::JobExtractionPrompt
        when "Ai::EmailExtractionPrompt", "email_extraction"
          ::Ai::EmailExtractionPrompt
        when "Ai::ResumeSkillExtractionPrompt", "resume_extraction"
          ::Ai::ResumeSkillExtractionPrompt
        else
          ::Ai::LlmPrompt
        end
      end

      # Returns filtered prompts based on params
      #
      # @return [ActiveRecord::Relation]
      def filtered_prompts
        prompts = ::Ai::LlmPrompt.all

        # Filter by type
        if params[:prompt_type].present?
          type_class = case params[:prompt_type]
          when "job_extraction" then "Ai::JobExtractionPrompt"
          when "email_extraction" then "Ai::EmailExtractionPrompt"
          when "resume_extraction" then "Ai::ResumeSkillExtractionPrompt"
          else params[:prompt_type]
          end
          prompts = prompts.where(type: type_class)
        end

        # Filter by active status
        if params[:active].present?
          case params[:active]
          when "true"
            prompts = prompts.where(active: true)
          when "false"
            prompts = prompts.where(active: false)
          end
        end

        # Search by name
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          prompts = prompts.where("name ILIKE :q OR description ILIKE :q", q: search_term)
        end

        # Sort
        case params[:sort]
        when "name"
          prompts = prompts.order(:name)
        when "type"
          prompts = prompts.order(:type, version: :desc)
        when "version"
          prompts = prompts.order(version: :desc)
        when "recent"
          prompts = prompts.order(created_at: :desc)
        else
          prompts = prompts.order(:type, version: :desc, created_at: :desc)
        end

        prompts
      end

      # Calculates overall stats
      #
      # @return [Hash]
      def calculate_stats
        base = ::Ai::LlmPrompt.all

        {
          total: base.count,
          active: base.where(active: true).count,
          inactive: base.where(active: false).count,
          by_type: base.group(:type).count.transform_keys { |k| k.demodulize.underscore.humanize }
        }
      end

      # Returns the current filter params
      #
      # @return [Hash]
      def filter_params
        params.permit(:search, :active, :sort, :page, :prompt_type)
      end

      # Strong params for prompt
      #
      # @return [ActionController::Parameters] Permitted params
      def prompt_params
        permitted = [ :name, :description, :prompt_template, :version, :active ]
        # Only allow type on create (STI discriminator shouldn't change after creation)
        permitted << :type if action_name == "create"

        # form_with with STI subclasses uses subclass param key (e.g., :ai_job_extraction_prompt)
        # Try common STI keys first, then fallback to :llm_prompt
        prompt_key = find_prompt_param_key
        params.require(prompt_key).permit(*permitted)
      end

      # Finds the correct param key for STI prompt models
      #
      # @return [Symbol] Param key to use
      def find_prompt_param_key
        # Check if we have an existing prompt with a known param_key
        if @prompt&.persisted?
          param_key = @prompt.model_name.param_key.to_sym
          return param_key if params.key?(param_key)
        end

        # Check for type in params to determine expected key
        type = params.dig(:llm_prompt, :type) || params[:prompt_type]
        if type.present?
          type_class = prompt_class_from_type(type)
          param_key = type_class.model_name.param_key.to_sym
          return param_key if params.key?(param_key)
        end

        # Check for any _prompt key
        prompt_key = params.keys.find { |k| k.to_s.end_with?("_prompt") }
        return prompt_key.to_sym if prompt_key

        # Fallback to base key
        :llm_prompt
      end

      # Returns prompt class from type string
      #
      # @param type [String] Type string
      # @return [Class] Prompt class
      def prompt_class_from_type(type)
        case type.to_s
        when "Ai::JobExtractionPrompt", "job_extraction"
          ::Ai::JobExtractionPrompt
        when "Ai::EmailExtractionPrompt", "email_extraction"
          ::Ai::EmailExtractionPrompt
        when "Ai::ResumeSkillExtractionPrompt", "resume_extraction"
          ::Ai::ResumeSkillExtractionPrompt
        else
          ::Ai::LlmPrompt
        end
      end
    end
  end
end
