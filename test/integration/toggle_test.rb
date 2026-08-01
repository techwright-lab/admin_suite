# frozen_string_literal: true

require "test_helper"

# Final review Finding 3: the gem hard-depends on turbo-rails (`turbo_stream`
# in `ResourcesController#toggle`, `turbo_frame_tag` throughout the resource
# views) but never declared it in the gemspec. Before that dependency is
# declared, this test exercises the exact path the review flagged as broken
# in a turbo-less host: `format.turbo_stream` inside `respond_to` raises the
# moment it's evaluated, because the `:turbo_stream` MIME type is unregistered
# without turbo-rails loaded. See `test/test_helper.rb`'s (now removed)
# `TurboFrameTestHelper`, which only ever patched `turbo_frame_tag` -- it
# never made `turbo_stream`/the MIME type real, so this branch was untestable
# until the real dependency was declared.
module ToggleFixtures
  class Widget
    extend ActiveModel::Naming

    attr_reader :id
    attr_accessor :active

    def initialize(id: 1, active: false)
      @id = id
      @active = active
    end

    def self.all
      ReadOnlyResourceFixtures::Relation.new([ new ])
    end

    def self.column_names
      %w[id active]
    end

    def self.primary_key
      "id"
    end

    def self.columns_hash
      { "id" => Struct.new(:type).new(:integer) }
    end

    def self.find(id)
      return new(id: 1, active: false) if id.to_s == "1"

      raise ActiveRecord::RecordNotFound
    end

    def to_param
      id.to_s
    end

    # `dom_id` (via `ActionView::RecordIdentifier#record_key_for_dom_id`)
    # calls `to_key` on the record -- `extend ActiveModel::Naming` alone
    # only supplies `model_name`, not `to_key`.
    def to_key
      [ id ]
    end

    def update!(attrs)
      attrs.each { |key, value| public_send("#{key}=", value) }
      true
    end
  end
end

module Admin
  module Resources
    class ToggleWidgetResource < Admin::Base::Resource
      model ToggleFixtures::Widget
      portal :ops
      section :observability

      index do
        columns do
          column :active, type: :toggle
        end
      end
    end
  end
end

module AdminSuite
  class ToggleTest < ActionDispatch::IntegrationTest
    include ActionView::RecordIdentifier

    BASE_PATH = "/internal/admin_suite/ops/toggle_widgets"

    test "toggle's turbo_stream branch replaces the toggle cell with the flipped state" do
      post "#{BASE_PATH}/1/toggle",
        params: { field: "active" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type

      target = dom_id(ToggleFixtures::Widget.new(id: 1), "active_toggle")
      assert_includes response.body, "<turbo-stream"
      assert_includes response.body, %(action="replace")
      assert_includes response.body, %(target="#{target}")
      # The record started with `active: false`; the toggle flips it to
      # `true` before rendering, so the replaced cell must reflect "on".
      assert_includes response.body, "is-on"
    end
  end
end
