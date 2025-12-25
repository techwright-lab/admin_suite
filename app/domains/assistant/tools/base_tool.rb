# frozen_string_literal: true

module Assistant
  module Tools
    class BaseTool
      def initialize(user:)
        @user = user
      end

      private

      attr_reader :user
    end
  end
end
