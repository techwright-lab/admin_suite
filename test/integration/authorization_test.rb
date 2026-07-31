# frozen_string_literal: true

require "test_helper"

# Reuses the in-memory fixture pattern from read_only_resource_test.rb.
module AuthzFixtures
  class Gadget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id: 1, name: "Gadget one")
      @id = id
      @name = name
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new([ new ])
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }

    def self.find(id)
      raise ActiveRecord::RecordNotFound unless id.to_s == "1"
      new
    end

    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end
end

module Admin
  module Resources
    class AuthzGadgetResource < Admin::Base::Resource
      model AuthzFixtures::Gadget
      portal :ops
      section :observability

      index do
        columns { column :name }
      end
    end
  end
end

module AdminSuite
  class AuthorizationTest < ActionDispatch::IntegrationTest
    BASE = "/internal/admin_suite/ops/authz_gadgets"

    def with_authorize(hook)
      saved = AdminSuite.config.authorize
      AdminSuite.config.authorize = hook
      yield
    ensure
      AdminSuite.config.authorize = saved
    end

    test "nil authorize hook allows requests" do
      with_authorize(nil) do
        get BASE
        assert_response :success
      end
    end

    test "falsy authorize denies with 403" do
      with_authorize(->(**) { false }) do
        get BASE
        assert_response :forbidden
      end
    end

    test "authorize receives actor, mapped action, resource, record, controller" do
      captured = nil
      hook = lambda do |actor:, action:, resource:, record:, controller:|
        captured = { action: action, resource: resource, record: record }
        true
      end

      with_authorize(hook) do
        get "#{BASE}/1"
      end

      assert_equal :read, captured[:action]
      assert_equal Admin::Resources::AuthzGadgetResource, captured[:resource]
      assert_instance_of AuthzFixtures::Gadget, captured[:record]
    end

    test "destroy maps to :destroy" do
      captured_action = nil
      with_authorize(->(action:, **) { captured_action = action; false }) do
        delete "#{BASE}/1"
      end
      assert_equal :destroy, captured_action
    end
  end
end
