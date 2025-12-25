# frozen_string_literal: true

require "redcarpet"
require "rouge"
require "rouge/plugins/redcarpet"

# MarkdownRenderer converts markdown text into safe HTML with syntax highlighting.
#
# Uses Redcarpet for markdown parsing, Rouge for syntax highlighting,
# and extracts a table of contents from headings.
#
# @example Basic usage (static method)
#   html = MarkdownRenderer.render(markdown_text)
#
# @example With TOC extraction (instance method)
#   renderer = MarkdownRenderer.new(markdown)
#   result = renderer.render
#   result[:html] # => safe HTML string with syntax-highlighted code
#   result[:toc]  # => [{level: 2, id: "section", text: "Section"}, ...]
#   result[:reading_time_minutes] # => Integer
#
class MarkdownRenderer
  attr_reader :markdown

  def initialize(markdown)
    @markdown = markdown.to_s
  end

  # Instance method for rendering with TOC extraction
  # @return [Hash{Symbol=>Object}]
  def render
    result = self.class.render_with_toc(markdown)

    {
      html: result[:html],
      toc: result[:toc],
      reading_time_minutes: reading_time_minutes
    }
  end

  # Static method for simple HTML rendering
  # @param text [String] The markdown text to render
  # @return [String] Safe HTML string
  def self.render(text)
    renderer = HtmlRenderer.new
    markdown = Redcarpet::Markdown.new(renderer, markdown_extensions)
    markdown.render(text).html_safe
  end

  # Static method for rendering with TOC extraction
  # @param text [String] The markdown text to render
  # @return [Hash{Symbol=>Object}]
  def self.render_with_toc(text)
    renderer = HtmlRenderer.new
    markdown = Redcarpet::Markdown.new(renderer, markdown_extensions)
    html = markdown.render(text).html_safe
    { html: html, toc: renderer.toc_items }
  end

  private

  def self.markdown_extensions
    {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      superscript: true,
      underline: true,
      no_intra_emphasis: true,
      space_after_headers: true,
      lax_spacing: true
    }
  end

  # Rough reading time estimate assuming 200 wpm.
  # @return [Integer]
  def reading_time_minutes
    words = markdown.scan(/\b[\p{L}\p{N}']+\b/).size
    [ (words / 200.0).ceil, 1 ].max
  end

  # Inner HTML renderer class with Rouge syntax highlighting
  class HtmlRenderer < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet

    # @return [Array<Hash>] Table of contents entries collected during rendering
    attr_reader :toc_items

    def initialize(extensions = {})
      super(extensions.merge(
        hard_wrap: true,
        link_attributes: { target: "_blank", rel: "noopener noreferrer" },
        with_toc_data: true
      ))
      @toc_items = []
      @heading_ids = Hash.new(0)
    end

    # Custom block code rendering with Rouge using CSS classes
    def block_code(code, language)
      language ||= "text"
      lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new

      # Use HTML formatter with CSS classes (not inline styles)
      formatter = Rouge::Formatters::HTML.new
      highlighted = formatter.format(lexer.lex(code))

      lang_label = language != "text" ? %(<span class="code-lang">#{language}</span>) : ""
      %(<div class="code-block">#{lang_label}<pre class="highlight #{language}"><code>#{highlighted}</code></pre></div>)
    end

    # Add classes to paragraphs for styling
    def paragraph(text)
      %(<p>#{text}</p>\n)
    end

    # Style blockquotes
    def block_quote(quote)
      %(<blockquote>#{quote}</blockquote>\n)
    end

    # Add anchor links to headers and collect TOC
    def header(text, header_level)
      base_slug = text.downcase.strip.gsub(/\s+/, "-").gsub(/[^\w-]/, "")
      base_slug = "section" if base_slug.blank?

      @heading_ids[base_slug] += 1
      slug = @heading_ids[base_slug] > 1 ? "#{base_slug}-#{@heading_ids[base_slug]}" : base_slug

      # Collect TOC items for h2, h3, h4
      if header_level >= 2 && header_level <= 4
        @toc_items << { level: header_level, id: slug, text: text }
      end

      %(<h#{header_level} id="#{slug}">#{text}</h#{header_level}>\n)
    end

    # Style horizontal rules
    def hrule
      %(<hr class="my-8">\n)
    end

    # Style tables
    def table(header, body)
      %(<table class="doc-table"><thead>#{header}</thead><tbody>#{body}</tbody></table>\n)
    end
  end
end
