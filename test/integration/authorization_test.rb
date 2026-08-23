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
        refute_includes response.body, "Gadget one"
      end
    end

    test "nil authorize result denies with 403 and does not disclose the record" do
      with_authorize(->(**) { nil }) do
        get "#{BASE}/1"
        assert_response :forbidden
        refute_includes response.body, "Gadget one"
      end
    end

    test "nil authorize result cannot mutate" do
      with_authorize(->(**) { nil }) do
        delete "#{BASE}/1"
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

    test "execute_action reaches the authorize hook with :execute before the action-name 404" do
      captured_action = nil
      with_authorize(->(action:, **) { captured_action = action; false }) do
        post "#{BASE}/1/execute_action/anything"
      end
      assert_equal :execute, captured_action
    end

    test "bulk_action reaches the authorize hook with :execute before the action-name 404" do
      captured_action = nil
      with_authorize(->(action:, **) { captured_action = action; false }) do
        post "#{BASE}/bulk_action/anything", params: { ids: [ "1" ] }
      end
      assert_equal :execute, captured_action
    end

    test "unregistered resource name 404s instead of constantizing a host model" do
      get "/internal/admin_suite/ops/strings"
      assert_response :not_found
    end

    test "unregistered resource name 404s on mutating verbs instead of reaching the model" do
      delete "/internal/admin_suite/ops/strings/1"
      assert_response :not_found
    end

    test "unregistered resource name 404s before the authorize hook ever runs" do
      hook_called = false
      with_authorize(->(**) { hook_called = true; false }) do
        get "/internal/admin_suite/ops/strings"
        assert_response :not_found
      end
      refute hook_called, "authorize hook must not run for an unregistered resource name"
    end
  end
end
