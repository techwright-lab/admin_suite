# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ResourcesControllerTest < ActiveSupport::TestCase
    class TestController < ResourcesController
      attr_writer :test_resource_config
      attr_reader :filter_calls, :paginated_scope

      def initialize
        super
        @filter_calls = 0
      end

      private

      def resource_config
        @test_resource_config
      end

      def filtered_collection
        @filter_calls += 1
        { total: 37 }
      end

      def paginate_collection(scope)
        @paginated_scope = scope
        [ Object.new, :paginated ]
      end
    end

    class StatsResource < Admin::Base::Resource
      index do
        stats do
          stat :legacy, -> { 11 }
          stat :filtered, ->(scope) { scope.fetch(:total) }
        end
      end
    end

    class BrokenStatsResource < Admin::Base::Resource
      index do
        stats do
          stat :broken, ->(_scope) { raise "boom" }
        end
      end
    end

    test "stats preserve zero arity calculators and pass the filtered scope to one arity calculators" do
      controller = TestController.new
      controller.test_resource_config = StatsResource
      scope = { total: 37 }

      stats = controller.send(:calculate_stats, scope)

      assert_equal 11, stats.first[:value]
      assert_equal 37, stats.second[:value]
    end

    test "stats preserve the existing calculator rescue behavior" do
      controller = TestController.new
      controller.test_resource_config = BrokenStatsResource

      assert_equal "N/A", controller.send(:calculate_stats, Object.new).first[:value]
    end

    test "index reuses one filtered unpaginated scope for stats and pagination" do
      controller = TestController.new
      controller.test_resource_config = StatsResource

      controller.index

      assert_equal 1, controller.filter_calls
      assert_equal({ total: 37 }, controller.paginated_scope)
      assert_equal 37, controller.instance_variable_get(:@stats).second[:value]
      assert_equal :paginated, controller.instance_variable_get(:@collection)
    end
  end
end
