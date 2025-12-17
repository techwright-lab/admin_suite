# frozen_string_literal: true

# Ensure markdown and HTML parsing libraries are loaded in all environments.
require "commonmarker"
require "nokogiri"

# MarkdownRenderer converts markdown text into safe HTML and extracts a table of contents.
#
# Uses CommonMarker for parsing and Nokogiri to add stable heading anchors.
#
# @example
#   rendered = MarkdownRenderer.new(markdown).render
#   rendered[:html] # => safe HTML string
#   rendered[:toc]  # => [{level: 2, id: "section", text: "Section"}, ...]
#   rendered[:reading_time_minutes] # => Integer
class MarkdownRenderer
  # @return [String]
  attr_reader :markdown

  # @param markdown [String]
  def initialize(markdown)
    @markdown = markdown.to_s
  end

  # Renders markdown to sanitized HTML and extracts TOC headings.
  #
  # @return [Hash{Symbol=>Object}]
  def render
    html = Commonmarker.to_html(markdown)

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    toc = add_heading_ids_and_build_toc!(fragment)

    rendered_html = sanitize_html(fragment.to_html)

    {
      html: rendered_html,
      toc: toc,
      reading_time_minutes: reading_time_minutes
    }
  end

  private

  # Adds stable IDs to headings and returns a TOC structure.
  #
  # @param fragment [Nokogiri::HTML::DocumentFragment]
  # @return [Array<Hash>]
  def add_heading_ids_and_build_toc!(fragment)
    used_ids = Hash.new(0)
    toc = []

    fragment.css("h2, h3, h4").each do |node|
      text = node.text.to_s.strip
      next if text.blank?

      base = text.parameterize
      base = "section" if base.blank?
      used_ids[base] += 1
      id = used_ids[base] > 1 ? "#{base}-#{used_ids[base]}" : base

      node["id"] ||= id

      toc << {
        level: node.name.delete_prefix("h").to_i,
        id: node["id"],
        text: text
      }
    end

    toc
  end

  # Sanitizes HTML output.
  #
  # @param html [String]
  # @return [String] safe HTML
  def sanitize_html(html)
    ActionController::Base.helpers.sanitize(
      html,
      tags: allowed_tags,
      attributes: allowed_attributes
    )
  end

  def allowed_tags
    %w[
      h1 h2 h3 h4 h5 h6
      p br
      ul ol li
      strong em b i
      code pre
      a
      blockquote hr
      table thead tbody tr th td
      span div
    ]
  end

  def allowed_attributes
    %w[class href target rel id]
  end

  # Rough reading time estimate assuming 200 wpm.
  #
  # @return [Integer]
  def reading_time_minutes
    words = markdown.scan(/\b[\p{L}\p{N}']+\b/).size
    [ (words / 200.0).ceil, 1 ].max
  end
end


