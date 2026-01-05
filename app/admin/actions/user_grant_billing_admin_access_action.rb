# frozen_string_literal: true

module Admin
  module Actions
    class UserGrantBillingAdminAccessAction < Admin::Base::ActionHandler
      def call
        Billing::AdminAccessService.new(user: record, actor: current_user).grant!
        success("Granted Admin/Developer billing access.")
      end
    end
  end
end
