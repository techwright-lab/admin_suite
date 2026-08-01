# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ActionExecutorRedirectTest < ActiveSupport::TestCase
    Action = Struct.new(:name, :label, keyword_init: true)

    test "AASM is not referenced as a bare constant" do
      source = File.read(File.expand_path("../../lib/admin/base/action_executor.rb", __dir__))
      refute_match(/rescue AASM::InvalidTransition/, source)
    end

    test "redirect target is derived for any action returning a persisted record" do
      executor = Admin::Base::ActionExecutor.new(RedirectFixtures::WidgetResource, :clone_widget, nil)
      url = executor.send(:redirect_url_for_action, Action.new(name: :clone_widget, label: "Clone"), RedirectFixtures::Widget.new)
      assert_equal "/internal/admin_suite/ops/redirect_widgets/42", url
    end

    test "no redirect for results that are not persisted records" do
      executor = Admin::Base::ActionExecutor.new(RedirectFixtures::WidgetResource, :ping, nil)
      assert_nil executor.send(:redirect_url_for_action, Action.new(name: :ping, label: "Ping"), true)
    end

    test "a plain RuntimeError from a model action surfaces its real message, not a NameError" do
      executor = Admin::Base::ActionExecutor.new(Admin::Resources::ExceptionHandlingBoomerResource, :kaboom, nil)
      result = executor.execute_member(ExceptionHandlingFixtures::Boomer.new)

      assert result.failure?
      assert_equal "Error: actual failure message", result.message
    end

    test "an exception whose class name contains InvalidTransition is reported as a friendly failure" do
      executor = Admin::Base::ActionExecutor.new(Admin::Resources::ExceptionHandlingStateMachineResource, :transition, nil)
      result = executor.execute_member(ExceptionHandlingFixtures::StateMachineWidget.new)

      assert result.failure?
      assert_equal "Invalid state transition: cannot transition from draft to published", result.message
    end
  end
end
