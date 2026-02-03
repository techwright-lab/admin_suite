# frozen_string_literal: true

module Admin
  module Base
    class ActionHandler
      attr_reader :record, :actor, :params

      alias_method :current_user, :actor

      def initialize(record, actor, params = {})
        @record = record
        @actor = actor
        @params = params
      end

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
