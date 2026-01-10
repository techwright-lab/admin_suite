# frozen_string_literal: true

require "test_helper"

class Labels::DedupeServiceTest < ActiveSupport::TestCase
  test "groups punctuation/whitespace variants" do
    labels = [
      "System Design",
      "system   design",
      "System-Design!"
    ]

    grouped = Labels::DedupeService.new(labels).grouped_counts
    assert_equal 1, grouped.size
    assert_equal 3, grouped.values.first[:count]
  end

  test "can group near-duplicates with strong token overlap" do
    labels = [
      "Ruby and Ruby on Rails backend development",
      "Ruby on Rails and backend architecture"
    ]

    grouped = Labels::DedupeService.new(labels, similarity_threshold: 0.82, overlap_threshold: 0.75).grouped_counts
    assert_equal 1, grouped.size
    assert_equal 2, grouped.values.first[:count]
  end

  test "does not group weakly related phrases" do
    labels = [
      "Technical leadership and ownership across full product lifecycle",
      "Technical leadership and mentoring"
    ]

    grouped = Labels::DedupeService.new(labels, similarity_threshold: 0.82, overlap_threshold: 0.75).grouped_counts
    assert_equal 2, grouped.size
  end
end

