# frozen_string_literal: true

module Admin
  module Base
    # Base class for action handlers.
    #
    # Implement custom action logic by subclassing this.
    #
    # @example
    #   class Admin::Actions::CompanyMergeAction < Admin::Base::ActionHandler
    #     def call
    #       target_company = Company.find(params[:target_company_id])
    #       Dedup::MergeCompanyService.new(source_company: record, target_company: target_company).run
    #       success("Merged into #{target_company.name}")
    #     end
    #   end
    class ActionHandler
      attr_reader :record, :current_user, :params

      # @param record [ActiveRecord::Base]
      # @param current_user [User]
      # @param params [Hash]
      def initialize(record, current_user, params = {})
        @record = record
        @current_user = current_user
        @params = params
      end

      # Override this method to implement the action.
      #
      # @return [Admin::Base::ActionExecutor::Result]
      def call
        raise NotImplementedError, "Subclasses must implement #call"
      end

      protected

      def success(message, redirect_url: nil)
        Admin::Base::ActionExecutor::Result.new(success: true, message: message, redirect_url: redirect_url, errors: [])
      end

      def failure(message, errors: [])
        Admin::Base::ActionExecutor::Result.new(success: false, message: message, redirect_url: nil, errors: errors)
      end
    end
  end
end
