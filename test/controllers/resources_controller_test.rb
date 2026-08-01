# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ResourcesControllerTest < ActiveSupport::TestCase
    class TestController < ResourcesController
      attr_writer :test_resource_config, :test_params
      attr_reader :filter_calls, :paginated_scope

      def initialize
        super
        @filter_calls = 0
      end

      def params
        @test_params ||= {}
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

    # Finding 3(a) of the whole-branch review: `set_resource`'s bare
    # `rescue ActiveRecord::RecordNotFound` is the masking variant. In a host
    # without ActiveRecord loaded, resolving that constant while dispatching
    # an exception raises `NameError`, destroying whatever the real error
    # was (here, a PORO model that doesn't implement `column_names`).
    class PoroWithoutColumns
      def self.column_names
        raise NoMethodError, "undefined method 'column_names' for #{name}"
      end
    end

    class PoroResourceConfig < Admin::Base::Resource
      model PoroWithoutColumns
    end

    # A model shape that implements just enough of the ActiveRecord surface
    # `set_resource`/`find_friendly_resource!` touch to exercise the genuine
    # `ActiveRecord::RecordNotFound` recovery path end-to-end.
    class SlugLookupModel
      Column = Struct.new(:type)
      Record = Struct.new(:id, :slug)

      def self.column_names
        %w[id slug]
      end

      def self.primary_key
        "id"
      end

      def self.columns_hash
        { "id" => Column.new(:string) }
      end

      def self.find(_id)
        raise ActiveRecord::RecordNotFound, "not found by primary key"
      end

      def self.find_by(slug:)
        slug == "the-slug" ? Record.new(42, "the-slug") : nil
      end
    end

    class SlugResourceConfig < Admin::Base::Resource
      model SlugLookupModel
    end

    test "set_resource still recovers via find_friendly_resource! on a genuine ActiveRecord::RecordNotFound" do
      controller = TestController.new
      controller.test_resource_config = SlugResourceConfig
      controller.test_params = { id: "the-slug" }

      controller.send(:set_resource)

      assert_equal 42, controller.send(:resource).id
    end

    test "set_resource propagates the original error instead of masking it with NameError" do
      controller = TestController.new
      controller.test_resource_config = PoroResourceConfig
      controller.test_params = { id: "1" }

      original = ActiveRecord::RecordNotFound
      ActiveRecord.send(:remove_const, :RecordNotFound)

      error = assert_raises(NoMethodError) { controller.send(:set_resource) }
      assert_match(/column_names/, error.message)
    ensure
      ActiveRecord.const_set(:RecordNotFound, original) unless defined?(ActiveRecord::RecordNotFound)
    end
  end
end
