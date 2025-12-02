# frozen_string_literal: true

# Helper for formatting extracted text content (descriptions, requirements, etc.)
#
# Provides smart formatting that:
# - Detects and renders bullet points as lists
# - Detects and renders numbered lists
# - Detects implicit lists (lines that look like list items)
# - Detects and formats hash/array data structures
# - Preserves paragraphs
# - Supports basic markdown rendering
# - Sanitizes HTML for security
#
# @example
#   <%= format_job_text(@job_listing.description) %>
module TextFormatterHelper
  # Patterns to detect Ruby hash/array syntax
  HASH_PATTERN = /\A\s*\{.*=>\s*.*\}\s*\z/m
  ARRAY_PATTERN = /\A\s*\[.*\]\s*\z/m
  HASH_ARROW_PATTERN = /["\']([^"\']+)["\']\s*=>\s*/
  # Patterns that indicate a line is likely a list item even without bullet markers
  IMPLICIT_LIST_PATTERNS = [
    /^You'll\s/i,           # "You'll be responsible for..."
    /^You\s+will\s/i,       # "You will design..."
    /^We're\s+looking/i,    # "We're looking for..."
    /^Must\s+have/i,        # "Must have experience..."
    /^Should\s+have/i,      # "Should have knowledge..."
    /^Experience\s+(with|in)/i,  # "Experience with..."
    /^Strong\s/i,           # "Strong communication skills"
    /^Excellent\s/i,        # "Excellent problem solving"
    /^Ability\s+to/i,       # "Ability to work..."
    /^Knowledge\s+of/i,     # "Knowledge of..."
    /^Familiarity\s+with/i, # "Familiarity with..."
    /^Proficiency\s+in/i,   # "Proficiency in..."
    /^Understanding\s+of/i, # "Understanding of..."
    /^Proven\s/i,           # "Proven track record..."
    /^Deep\s+expertise/i,   # "Deep expertise in..."
    /^\d+\+?\s*years?/i,    # "5+ years experience"
    /^Bachelor'?s?\s/i,     # "Bachelor's degree"
    /^Master'?s?\s/i,       # "Master's degree"
    /^PhD\s/i,              # "PhD in..."
    /^Build\s/i,            # "Build scalable systems"
    /^Design\s/i,           # "Design and implement..."
    /^Develop\s/i,          # "Develop new features"
    /^Lead\s/i,             # "Lead a team of..."
    /^Manage\s/i,           # "Manage projects..."
    /^Work\s+(with|closely)/i, # "Work with cross-functional teams"
    /^Collaborate\s/i,      # "Collaborate with..."
    /^Own\s/i,              # "Own the entire..."
    /^Drive\s/i             # "Drive technical decisions"
  ].freeze

  # Formats job listing text with smart detection and markdown support
  #
  # @param [String] text The raw text to format
  # @param [Hash] options Formatting options
  # @option options [Boolean] :markdown Enable markdown parsing (default: true)
  # @option options [Boolean] :detect_lists Auto-detect bullet/numbered lists (default: true)
  # @option options [Boolean] :linkify Convert URLs to links (default: true)
  # @return [String] Formatted HTML
  def format_job_text(text, options = {})
    return "" if text.blank?

    options = {
      markdown: true,
      detect_lists: true,
      detect_implicit_lists: true,
      linkify: true
    }.merge(options)

    formatted = text.to_s.dup

    # First, check if this looks like a Ruby hash or array
    if looks_like_ruby_data?(formatted)
      formatted = format_ruby_data(formatted)
    # Next, try to detect if it looks like markdown
    elsif options[:markdown] && looks_like_markdown?(formatted)
      formatted = render_markdown(formatted)
    else
      # Convert detected lists to HTML (including implicit lists)
      if options[:detect_lists]
        formatted = convert_lists_to_html(formatted, detect_implicit: options[:detect_implicit_lists])
      end
      formatted = convert_paragraphs_to_html(formatted)
    end

    # Convert URLs to links
    if options[:linkify]
      formatted = linkify_urls(formatted)
    end

    # Sanitize and return
    sanitize(formatted, tags: allowed_tags, attributes: allowed_attributes)
  end

  # Formats text specifically for requirements/responsibilities lists
  # More aggressive about detecting list items
  #
  # @param [String] text The raw text
  # @return [String] Formatted HTML
  def format_list_text(text)
    return "" if text.blank?

    formatted = text.to_s.dup

    # Always try to detect lists for requirements/responsibilities
    if looks_like_markdown?(formatted)
      formatted = render_markdown(formatted)
    else
      # Use aggressive implicit list detection for requirements/responsibilities
      formatted = convert_lists_to_html(formatted, detect_implicit: true, force_list: true)
      formatted = convert_paragraphs_to_html(formatted)
    end

    sanitize(formatted, tags: allowed_tags, attributes: allowed_attributes)
  end

  # Formats key-value pairs for display (e.g., "Contract Type: B2B")
  #
  # @param [String] text Text containing key-value pairs
  # @return [String] Formatted HTML with styled key-value display
  def format_key_value_text(text)
    return "" if text.blank?

    lines = text.to_s.strip.split("\n").map(&:strip).reject(&:blank?)

    # Check if this looks like key-value data
    kv_pairs = lines.map do |line|
      if line.match?(/^([^:]+):\s*(.+)$/)
        match = line.match(/^([^:]+):\s*(.+)$/)
        { key: match[1].strip, value: match[2].strip }
      else
        { text: line }
      end
    end

    # If most lines are key-value pairs, render as definition list
    kv_count = kv_pairs.count { |p| p[:key] }
    if kv_count >= (lines.count * 0.5) && kv_count >= 2
      # Sanitize the rendered key-value list HTML
      sanitize(render_key_value_list(kv_pairs), tags: allowed_tags, attributes: allowed_attributes)
    else
      # Fall back to regular list formatting
      format_list_text(text)
    end
  end

  # Checks if text appears to contain markdown formatting
  #
  # @param [String] text The text to check
  # @return [Boolean] True if markdown-like
  def looks_like_markdown?(text)
    return false if text.blank?

    # Check for common markdown patterns
    markdown_patterns = [
      /^#+\s/m,           # Headers
      /^\s*[-*+]\s+/m,    # Unordered lists
      /^\s*\d+\.\s+/m,    # Ordered lists
      /\*\*[^*]+\*\*/,    # Bold
      /\*[^*]+\*/,        # Italic
      /`[^`]+`/,          # Code
      /\[[^\]]+\]\([^)]+\)/ # Links
    ]

    markdown_patterns.any? { |pattern| text.match?(pattern) }
  end

  # Checks if text looks like Ruby hash or array syntax
  #
  # @param [String] text The text to check
  # @return [Boolean] True if it looks like Ruby data
  def looks_like_ruby_data?(text)
    return false if text.blank?

    stripped = text.to_s.strip

    # Check for hash arrow syntax {"key" => "value"} or symbol keys {:key => "value"}
    return true if stripped.match?(HASH_PATTERN) && stripped.include?("=>")

    # Check for array of hashes [{...}, {...}]
    return true if stripped.match?(ARRAY_PATTERN) && stripped.include?("=>")

    false
  end

  # Formats Ruby hash/array data into readable HTML
  #
  # @param [String] text The Ruby data string
  # @return [String] Formatted HTML
  def format_ruby_data(text)
    stripped = text.to_s.strip

    begin
      # Try to safely parse the Ruby-like data
      parsed = parse_ruby_data(stripped)
      render_parsed_data(parsed)
    rescue StandardError => e
      Rails.logger.warn("Failed to parse Ruby data: #{e.message}")
      # Fall back to basic formatting if parsing fails
      format_ruby_data_fallback(stripped)
    end
  end

  # Parses Ruby-like hash/array syntax
  #
  # @param [String] text The text to parse
  # @return [Hash, Array, String] Parsed data
  def parse_ruby_data(text)
    # Replace Ruby hash rockets with JSON-like syntax for parsing
    # Convert "key" => "value" to "key": "value"
    json_like = text.dup

    # Handle symbol keys like :key => to "key":
    json_like.gsub!(/:(\w+)\s*=>/, '"\1":')

    # Handle string keys like "key" => to "key":
    json_like.gsub!(/["']([^"']+)["']\s*=>/, '"\1":')

    # Try to parse as JSON
    JSON.parse(json_like)
  rescue JSON::ParserError
    # If JSON parsing fails, return the original text
    text
  end

  # Renders parsed data into HTML
  #
  # @param [Object] data The parsed data
  # @param [Integer] depth Current nesting depth
  # @return [String] HTML output
  def render_parsed_data(data, depth = 0)
    case data
    when Hash
      render_hash_data(data, depth)
    when Array
      if data.first.is_a?(Hash)
        render_array_of_hashes(data, depth)
      else
        render_simple_array(data, depth)
      end
    else
      "<p class=\"text-gray-600 dark:text-gray-400\">#{ERB::Util.html_escape(data.to_s)}</p>"
    end
  end

  # Renders a hash as a definition list
  #
  # @param [Hash] hash The hash to render
  # @param [Integer] depth Current depth
  # @return [String] HTML
  def render_hash_data(hash, depth = 0)
    items = hash.map do |key, value|
      formatted_key = humanize_key(key.to_s)
      formatted_value = format_hash_value(value, depth)

      <<~HTML
        <div class="flex flex-col sm:flex-row sm:gap-2 py-1.5">
          <dt class="text-sm font-medium text-gray-700 dark:text-gray-300 sm:min-w-[140px]">#{ERB::Util.html_escape(formatted_key)}</dt>
          <dd class="text-sm text-gray-600 dark:text-gray-400">#{formatted_value}</dd>
        </div>
      HTML
    end.join

    "<dl class=\"divide-y divide-gray-100 dark:divide-gray-700\">#{items}</dl>"
  end

  # Formats a hash value for display
  #
  # @param [Object] value The value to format
  # @param [Integer] depth Current depth
  # @return [String] Formatted HTML
  def format_hash_value(value, depth)
    case value
    when Array
      if value.all? { |v| v.is_a?(String) || v.is_a?(Numeric) }
        # Simple array of values - render as comma-separated or pills
        pills = value.map do |v|
          "<span class=\"inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 mr-1 mb-1\">#{ERB::Util.html_escape(v)}</span>"
        end.join
        "<div class=\"flex flex-wrap\">#{pills}</div>"
      else
        render_parsed_data(value, depth + 1)
      end
    when Hash
      render_parsed_data(value, depth + 1)
    else
      ERB::Util.html_escape(value.to_s)
    end
  end

  # Renders an array of hashes (like recruitment process steps)
  #
  # @param [Array<Hash>] array The array of hashes
  # @param [Integer] depth Current depth
  # @return [String] HTML
  def render_array_of_hashes(array, depth = 0)
    items = array.map.with_index do |item, index|
      # Try to find a name/title/step key for the header
      header = item["name"] || item["title"] || item["step"] || "Item #{index + 1}"
      header = "Step #{item['step']}: #{item['name']}" if item["step"] && item["name"]

      details = item.except("name", "title", "step").map do |key, value|
        formatted_key = humanize_key(key.to_s)
        formatted_value = value.is_a?(Array) ? value.join(", ") : value.to_s
        "<span class=\"text-gray-500 dark:text-gray-400\">#{ERB::Util.html_escape(formatted_key)}:</span> #{ERB::Util.html_escape(formatted_value)}"
      end.join(" • ")

      <<~HTML
        <li class="py-2">
          <div class="font-medium text-gray-800 dark:text-gray-200">#{ERB::Util.html_escape(header)}</div>
          <div class="text-sm text-gray-600 dark:text-gray-400 mt-0.5">#{details}</div>
        </li>
      HTML
    end.join

    "<ol class=\"divide-y divide-gray-100 dark:divide-gray-700 list-none\">#{items}</ol>"
  end

  # Renders a simple array as a list
  #
  # @param [Array] array The array to render
  # @param [Integer] depth Current depth
  # @return [String] HTML
  def render_simple_array(array, depth = 0)
    items = array.map do |item|
      "<li class=\"py-1\">#{ERB::Util.html_escape(item.to_s)}</li>"
    end.join

    "<ul class=\"list-disc list-inside space-y-1 text-gray-600 dark:text-gray-400\">#{items}</ul>"
  end

  # Humanizes a snake_case or camelCase key
  #
  # @param [String] key The key to humanize
  # @return [String] Humanized key
  def humanize_key(key)
    key.to_s
       .gsub(/([a-z])([A-Z])/, '\1 \2')  # Split camelCase
       .gsub("_", " ")                     # Split snake_case
       .titleize
  end

  # Fallback formatting for Ruby data that couldn't be parsed
  #
  # @param [String] text The original text
  # @return [String] Formatted HTML
  def format_ruby_data_fallback(text)
    # Try to extract key-value pairs from the string representation
    pairs = []
    text.scan(/["']([^"']+)["']\s*=>\s*["']?([^"',}\]]+)["']?/) do |key, value|
      pairs << { key: humanize_key(key), value: value.strip }
    end

    if pairs.any?
      items = pairs.map do |pair|
        <<~HTML
          <div class="flex flex-col sm:flex-row sm:gap-2 py-1">
            <dt class="text-sm font-medium text-gray-700 dark:text-gray-300 sm:min-w-[140px]">#{ERB::Util.html_escape(pair[:key])}</dt>
            <dd class="text-sm text-gray-600 dark:text-gray-400">#{ERB::Util.html_escape(pair[:value])}</dd>
          </div>
        HTML
      end.join

      "<dl class=\"divide-y divide-gray-100 dark:divide-gray-700\">#{items}</dl>"
    else
      # Just show the raw text with better formatting
      "<p class=\"text-gray-600 dark:text-gray-400 font-mono text-sm\">#{ERB::Util.html_escape(text)}</p>"
    end
  end

  private

  # Renders key-value pairs as a styled definition list
  #
  # @param [Array<Hash>] pairs Array of key-value pairs
  # @return [String] HTML
  def render_key_value_list(pairs)
    items = pairs.map do |pair|
      if pair[:key]
        <<~HTML
          <div class="flex flex-col sm:flex-row sm:gap-2 py-1">
            <dt class="text-sm font-medium text-gray-700 dark:text-gray-300 sm:min-w-[140px]">#{ERB::Util.html_escape(pair[:key])}</dt>
            <dd class="text-sm text-gray-600 dark:text-gray-400">#{ERB::Util.html_escape(pair[:value])}</dd>
          </div>
        HTML
      else
        "<p class=\"text-sm text-gray-600 dark:text-gray-400 py-1\">#{ERB::Util.html_escape(pair[:text])}</p>"
      end
    end.join

    "<dl class=\"divide-y divide-gray-100 dark:divide-gray-700\">#{items}</dl>"
  end

  # Renders markdown to HTML using a simple parser
  #
  # @param [String] text The markdown text
  # @return [String] HTML output
  def render_markdown(text)
    html = text.dup

    # Headers
    html.gsub!(/^### (.+)$/m, '<h4 class="text-base font-semibold text-gray-900 dark:text-white mt-4 mb-2">\1</h4>')
    html.gsub!(/^## (.+)$/m, '<h3 class="text-lg font-semibold text-gray-900 dark:text-white mt-4 mb-2">\1</h3>')
    html.gsub!(/^# (.+)$/m, '<h2 class="text-xl font-semibold text-gray-900 dark:text-white mt-4 mb-2">\1</h2>')

    # Bold and italic
    html.gsub!(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
    html.gsub!(/\*([^*]+)\*/, '<em>\1</em>')

    # Inline code
    html.gsub!(/`([^`]+)`/, '<code class="px-1.5 py-0.5 bg-gray-100 dark:bg-gray-700 rounded text-sm font-mono">\1</code>')

    # Convert lists and paragraphs
    html = convert_lists_to_html(html, detect_implicit: true)
    html = convert_paragraphs_to_html(html)

    html
  end

  # Converts detected bullet and numbered lists to HTML
  # Also detects implicit lists (lines that look like list items)
  #
  # @param [String] text The text
  # @param [Boolean] detect_implicit Whether to detect implicit list items
  # @param [Boolean] force_list Whether to force list rendering for newline-separated items
  # @return [String] Text with HTML lists
  def convert_lists_to_html(text, detect_implicit: false, force_list: false)
    lines = text.split("\n")
    result = []
    current_list_type = nil
    list_items = []

    # Check if we should force list mode (multiple short lines that look like items)
    if force_list
      non_empty_lines = lines.map(&:strip).reject(&:blank?)
      if non_empty_lines.length >= 3 && non_empty_lines.all? { |l| l.length < 200 }
        # Check if most lines look like list items
        implicit_count = non_empty_lines.count { |l| looks_like_implicit_list_item?(l) }
        force_list = implicit_count >= (non_empty_lines.length * 0.5)
      else
        force_list = false
      end
    end

    lines.each do |line|
      stripped = line.strip

      # Detect explicit bullet points (-, *, •, ►, ▪)
      if stripped.match?(/^[-*•►▪]\s+/)
        if current_list_type != :ul
          result << close_list(current_list_type, list_items) if current_list_type
          current_list_type = :ul
          list_items = []
        end
        list_items << stripped.sub(/^[-*•►▪]\s+/, "")

      # Detect numbered lists (1., 2., a., b., etc.)
      elsif stripped.match?(/^(\d+|[a-zA-Z])[.)]\s+/)
        if current_list_type != :ol
          result << close_list(current_list_type, list_items) if current_list_type
          current_list_type = :ol
          list_items = []
        end
        list_items << stripped.sub(/^(\d+|[a-zA-Z])[.)]\s+/, "")

      # Detect implicit list items (if enabled)
      elsif (detect_implicit || force_list) && stripped.present? && looks_like_implicit_list_item?(stripped)
        if current_list_type != :ul_implicit
          result << close_list(current_list_type, list_items) if current_list_type
          current_list_type = :ul_implicit
          list_items = []
        end
        list_items << stripped

      else
        # Close any open list
        if current_list_type
          result << close_list(current_list_type, list_items)
          current_list_type = nil
          list_items = []
        end
        result << line
      end
    end

    # Close final list if any
    result << close_list(current_list_type, list_items) if current_list_type

    result.join("\n")
  end

  # Checks if a line looks like an implicit list item
  #
  # @param [String] line The line to check
  # @return [Boolean] True if it looks like a list item
  def looks_like_implicit_list_item?(line)
    return false if line.blank?
    return false if line.length > 300 # Too long to be a list item

    IMPLICIT_LIST_PATTERNS.any? { |pattern| line.match?(pattern) }
  end

  # Closes a list and returns HTML
  #
  # @param [Symbol] list_type :ul, :ol, or :ul_implicit
  # @param [Array<String>] items List items
  # @return [String] HTML list
  def close_list(list_type, items)
    return "" if items.empty?

    tag = list_type == :ol ? "ol" : "ul"
    list_class = case list_type
    when :ol
                   "list-decimal list-inside space-y-2"
    when :ul_implicit
                   "space-y-2" # No bullets for implicit lists, just spacing
    else
                   "list-disc list-inside space-y-2"
                 end

    item_class = list_type == :ul_implicit ? "flex items-start gap-2" : ""
    bullet_html = list_type == :ul_implicit ? '<span class="text-primary-500 mt-1 flex-shrink-0">•</span>' : ""

    items_html = items.map do |item|
      if list_type == :ul_implicit
        "<li class=\"#{item_class}\">#{bullet_html}<span>#{ERB::Util.html_escape(item)}</span></li>"
      else
        "<li class=\"py-1\">#{ERB::Util.html_escape(item)}</li>"
      end
    end.join("\n")

    "<#{tag} class=\"#{list_class} text-gray-600 dark:text-gray-400 my-3\">#{items_html}</#{tag}>"
  end

  # Converts text paragraphs to HTML <p> tags
  #
  # @param [String] text The text
  # @return [String] Text with HTML paragraphs
  def convert_paragraphs_to_html(text)
    # Split by double newlines (or single newlines followed by blank lines)
    paragraphs = text.split(/\n\n+/)

    paragraphs.map do |para|
      para = para.strip
      next "" if para.blank?

      # Don't wrap if it's already a block element
      if para.start_with?("<h", "<ul", "<ol", "<div", "<p", "<dl")
        para
      else
        # Replace single newlines with <br> within paragraphs
        content = para.gsub(/\n/, "<br>")
        "<p class=\"mb-3 text-gray-600 dark:text-gray-400\">#{content}</p>"
      end
    end.join("\n")
  end

  # Converts URLs in text to clickable links
  #
  # @param [String] text The text
  # @return [String] Text with linked URLs
  def linkify_urls(text)
    url_pattern = %r{(https?://[^\s<>"]+)}

    text.gsub(url_pattern) do |url|
      "<a href=\"#{ERB::Util.html_escape(url)}\" target=\"_blank\" rel=\"noopener\" class=\"text-primary-600 dark:text-primary-400 hover:underline\">#{ERB::Util.html_escape(url)}</a>"
    end
  end

  # Returns allowed HTML tags for sanitization
  #
  # @return [Array<String>] Allowed tags
  def allowed_tags
    %w[h2 h3 h4 p br ul ol li strong em b i code a span div dl dt dd]
  end

  # Returns allowed HTML attributes for sanitization
  #
  # @return [Array<String>] Allowed attributes
  def allowed_attributes
    %w[class href target rel]
  end
end
