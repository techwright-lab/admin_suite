# frozen_string_literal: true

module Admin
  module Base
    # Executes admin actions (single, bulk, and collection actions)
    #
    # Handles the execution of actions defined in resource classes,
    # including permission checks, confirmation handling, and result processing.
    #
    # @example Single action
    #   executor = Admin::Base::ActionExecutor.new(CompanyResource, :disable, Current.user)
    #   result = executor.execute_member(company)
    #
    # @example Bulk action
    #   executor = Admin::Base::ActionExecutor.new(CompanyResource, :bulk_disable, Current.user)
    #   result = executor.execute_bulk([company1, company2])
    class ActionExecutor
      attr_reader :resource_class, :action_name, :current_user

      # Result of an action execution
      Result = Struct.new(:success, :message, :redirect_url, :errors, keyword_init: true) do
        def success?
          success
        end

        def failure?
          !success
        end
      end

      # Initializes the action executor
      #
      # @param resource_class [Class] The resource class
      # @param action_name [Symbol] The action name
      # @param current_user [User] The current user executing the action
      def initialize(resource_class, action_name, current_user)
        @resource_class = resource_class
        @action_name = action_name
        @current_user = current_user
      end

      # Executes a member action on a single record
      #
      # @param record [ActiveRecord::Base] The record to act on
      # @param params [Hash] Additional parameters
      # @return [Result]
      def execute_member(record, params = {})
        action = find_member_action
        return failure_result("Action not found") unless action

        return failure_result("Condition not met") unless condition_met?(action, record)

        execute_action(action, record, params)
      end

      # Executes a bulk action on multiple records
      #
      # @param records [Array<ActiveRecord::Base>] Records to act on
      # @param params [Hash] Additional parameters
      # @return [Result]
      def execute_bulk(records, params = {})
        action = find_bulk_action
        return failure_result("Action not found") unless action

        results = records.map do |record|
          execute_action(action, record, params)
        end

        success_count = results.count(&:success?)
        failure_count = results.count(&:failure?)

        if failure_count.zero?
          success_result("Successfully processed #{success_count} records")
        elsif success_count.zero?
          failure_result("Failed to process all #{failure_count} records")
        else
          success_result("Processed #{success_count} records, #{failure_count} failed")
        end
      end

      # Executes a collection action
      #
      # @param scope [ActiveRecord::Relation] The collection scope
      # @param params [Hash] Additional parameters
      # @return [Result]
      def execute_collection(scope, params = {})
        action = find_collection_action
        return failure_result("Action not found") unless action

        execute_action(action, scope, params)
      end

      # Returns the action definition
      #
      # @return [ActionDefinition, nil]
      def action_definition
        find_member_action || find_bulk_action || find_collection_action
      end

      private

      def actions_config
        @resource_class.actions_config
      end

      def find_member_action
        return nil unless actions_config

        actions_config.member_actions.find { |a| a.name == action_name }
      end

      def find_bulk_action
        return nil unless actions_config

        actions_config.bulk_actions.find { |a| a.name == action_name }
      end

      def find_collection_action
        return nil unless actions_config

        actions_config.collection_actions.find { |a| a.name == action_name }
      end

      def condition_met?(action, record)
        if action.if_condition.present?
          return record.instance_exec(&action.if_condition)
        end

        if action.unless_condition.present?
          return !record.instance_exec(&action.unless_condition)
        end

        true
      end

      def execute_action(action, target, params)
        model_class = resource_class.model_class

        # Try to find a method on the model first
        if target.respond_to?(action.name)
          execute_model_method(target, action)
        elsif target.respond_to?("#{action.name}!")
          execute_model_method(target, action, bang: true)
        else
          # Try to find an action handler class
          handler_class = find_handler_class(action)
          if handler_class
            execute_handler(handler_class, target, params)
          else
            failure_result("No handler found for action: #{action.name}")
          end
        end
      rescue StandardError => e
        failure_result("Error: #{e.message}")
      end

      def execute_model_method(record, action, bang: false)
        method_name = bang ? "#{action.name}!" : action.name
        record.public_send(method_name)
        success_result("#{action.label} completed successfully")
      rescue ActiveRecord::RecordInvalid => e
        failure_result("Validation failed: #{e.record.errors.full_messages.join(', ')}")
      rescue AASM::InvalidTransition => e
        failure_result("Invalid state transition: #{e.message}")
      end

      def find_handler_class(action)
        handler_name = "#{resource_class.resource_name.camelize}#{action.name.to_s.camelize}Action"
        "Admin::Actions::#{handler_name}".constantize
      rescue NameError
        nil
      end

      def execute_handler(handler_class, target, params)
        handler = handler_class.new(target, current_user, params)
        handler.call
      end

      def success_result(message, redirect_url: nil)
        Result.new(success: true, message: message, redirect_url: redirect_url, errors: [])
      end

      def failure_result(message, errors: [])
        Result.new(success: false, message: message, redirect_url: nil, errors: errors)
      end
    end

    # Base class for action handlers
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

      def initialize(record, current_user, params = {})
        @record = record
        @current_user = current_user
        @params = params
      end

      # Override this method to implement the action
      #
      # @return [ActionExecutor::Result]
      def call
        raise NotImplementedError, "Subclasses must implement #call"
      end

      protected

      def success(message, redirect_url: nil)
        ActionExecutor::Result.new(success: true, message: message, redirect_url: redirect_url, errors: [])
      end

      def failure(message, errors: [])
        ActionExecutor::Result.new(success: false, message: message, redirect_url: nil, errors: errors)
      end
    end
  end
end

