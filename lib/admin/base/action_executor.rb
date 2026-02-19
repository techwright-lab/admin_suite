# frozen_string_literal: true

module Admin
  module Base
    class ActionExecutor
      attr_reader :resource_class, :action_name, :actor

      alias_method :current_user, :actor

      Result = Struct.new(:success, :message, :redirect_url, :errors, keyword_init: true) do
        def success? = success
        def failure? = !success
      end

      # Track whether action handlers have been loaded to avoid repeated expensive globs
      @handlers_loaded = false

      class << self
        attr_accessor :handlers_loaded
      end

      def initialize(resource_class, action_name, actor)
        @resource_class = resource_class
        @action_name = action_name
        @actor = actor
      end

      def execute_member(record, params = {})
        action = find_member_action
        return failure_result("Action not found") unless action
        return failure_result("Condition not met") unless condition_met?(action, record)
        execute_action(action, record, params)
      end

      def execute_bulk(records, params = {})
        action = find_bulk_action
        return failure_result("Action not found") unless action

        results = records.map { |record| execute_action(action, record, params) }
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

      def execute_collection(scope, params = {})
        action = find_collection_action
        return failure_result("Action not found") unless action
        execute_action(action, scope, params)
      end

      def action_definition
        find_member_action || find_bulk_action || find_collection_action
      end

      private

      def actions_config = @resource_class.actions_config

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
        return evaluate_condition(action.if_condition, record) if action.if_condition.present?
        return !evaluate_condition(action.unless_condition, record) if action.unless_condition.present?
        true
      end

      def evaluate_condition(condition_proc, record)
        condition_proc.arity.zero? ? record.instance_exec(&condition_proc) : condition_proc.call(record)
      end

      def execute_action(action, target, params)
        result =
          if target.respond_to?(action.name)
            execute_model_method(target, action)
          elsif target.respond_to?("#{action.name}!")
            execute_model_method(target, action, bang: true)
          else
            handler_class = find_handler_class(action)
            handler_class ? execute_handler(handler_class, target, params) : failure_result("No handler found for action: #{action.name}")
          end

        notify_action_executed(action, target, params, result)
        result
      rescue StandardError => e
        result = failure_result("Error: #{e.message}")
        notify_action_executed(action, target, params, result)
        result
      end

      def execute_model_method(record, action, bang: false)
        method_name = bang ? "#{action.name}!" : action.name
        action_result = record.public_send(method_name)
        return action_result if action_result.is_a?(Result)

        success_result(
          "#{action.label} completed successfully",
          redirect_url: redirect_url_for_action(action, action_result)
        )
      rescue ActiveRecord::RecordInvalid => e
        failure_result("Validation failed: #{e.record.errors.full_messages.join(', ')}")
      rescue AASM::InvalidTransition => e
        failure_result("Invalid state transition: #{e.message}")
      end

      def redirect_url_for_action(action, action_result)
        return nil unless action.name.to_sym == :duplicate
        return nil unless action_result.respond_to?(:persisted?) && action_result.persisted?
        return nil unless resource_class.respond_to?(:portal_name) && resource_class.respond_to?(:resource_name_plural)

        AdminSuite::Engine.routes.url_helpers.resource_path(
          portal: resource_class.portal_name,
          resource_name: resource_class.resource_name_plural,
          id: action_result.to_param
        )
      rescue StandardError
        nil
      end

      def find_handler_class(action)
        if defined?(AdminSuite) && AdminSuite.config.resolve_action_handler.present?
          resolved = AdminSuite.config.resolve_action_handler.call(resource_class, action.name)
          return resolved if resolved
        end

        handler_name = "#{resource_class.resource_name.camelize}#{action.name.to_s.camelize}Action"
        handler_constant = "Admin::Actions::#{handler_name}"
        handler_constant.constantize
      rescue NameError
        # In many host apps, action handlers live under `app/admin/actions/**`.
        # Rails treats `app/admin` as a Zeitwerk root, which means Zeitwerk expects
        # top-level constants (e.g. `Actions::Foo`) unless the host configures
        # a namespace mapping. AdminSuite avoids requiring host Zeitwerk setup by
        # loading handler files via `AdminSuite.config.action_globs` when needed.
        load_action_handlers_for_admin_suite!

        handler_name = "#{resource_class.resource_name.camelize}#{action.name.to_s.camelize}Action"
        "Admin::Actions::#{handler_name}".constantize
      rescue NameError
        nil
      end

      def execute_handler(handler_class, target, params)
        handler_class.new(target, actor, params).call
      end

      def success_result(message, redirect_url: nil)
        Result.new(success: true, message: message, redirect_url: redirect_url, errors: [])
      end

      def failure_result(message, errors: [])
        Result.new(success: false, message: message, redirect_url: nil, errors: errors)
      end

      def notify_action_executed(action, target, params, result)
        return unless defined?(AdminSuite)
        hook = AdminSuite.config.on_action_executed
        return unless hook

        hook.call(
          actor: actor,
          action_name: action.name,
          resource_class: resource_class,
          subject: target,
          params: params,
          result: result
        )
      rescue StandardError
        nil
      end

      def load_action_handlers_for_admin_suite!
        return unless defined?(AdminSuite)

        # Track whether we've already loaded handlers to avoid expensive repeated globs.
        # In development, this flag is reset by the Rails reloader (see engine.rb).
        # In production/test, it persists for the process lifetime.
        return if self.class.handlers_loaded

        files = Array(AdminSuite.config.action_globs).flat_map { |g| Dir[g] }.uniq

        # Set the flag even if no files found - we've done the glob and shouldn't repeat it
        if files.empty?
          self.class.handlers_loaded = true
          return
        end

        files.each do |file|
          begin
            if Rails.env.development?
              load file
            else
              require file
            end
          rescue StandardError, ScriptError => e
            log_action_handler_load_error(file, e)

            # Fail fast in dev/test so broken handler files are immediately discoverable.
            raise if Rails.env.development? || Rails.env.test?
          end
        end

        # We attempted to load the configured handlers. Avoid repeating expensive globs
        # and file loads for the rest of the process lifetime.
        self.class.handlers_loaded = true
      end

      def log_action_handler_load_error(file, error)
        message = "[AdminSuite] Failed to load action handler file #{file}: #{error.class}: #{error.message}"

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error(message)

          backtrace = Array(error.backtrace).take(20).join("\n")
          Rails.logger.error(backtrace) unless backtrace.empty?
        else
          warn(message)
        end
      rescue StandardError
        nil
      end
    end
  end
end
