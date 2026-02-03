# frozen_string_literal: true

module LlmProviders
  # Anthropic Claude provider for LLM completions
  #
  # Uses the Anthropic Ruby SDK with streaming for efficient long-running requests.
  # Includes rate limiting via AnthropicRateLimiterService.
  #
  # Supports multimodal input:
  # - Images: JPEG, PNG, GIF, WebP
  # - Documents: PDF (native), DOCX (via text extraction)
  class AnthropicProvider < BaseProvider
    # Supported image MIME types
    SUPPORTED_IMAGE_TYPES = %w[
      image/jpeg
      image/png
      image/gif
      image/webp
    ].freeze

    # Natively supported document MIME types (sent as-is)
    NATIVE_DOCUMENT_TYPES = %w[
      application/pdf
    ].freeze

    # Document types requiring text extraction before sending
    TEXT_EXTRACTION_TYPES = %w[
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
    ].freeze

    # All supported document MIME types
    SUPPORTED_DOCUMENT_TYPES = (NATIVE_DOCUMENT_TYPES + TEXT_EXTRACTION_TYPES).freeze

    # All supported media types
    SUPPORTED_MEDIA_TYPES = (SUPPORTED_IMAGE_TYPES + SUPPORTED_DOCUMENT_TYPES).freeze

    # Sends a prompt to Claude and returns the response
    #
    # @param prompt [String] The prompt text
    # @param options [Hash] Optional parameters
    #   @option options [Integer] :max_tokens Maximum tokens in response
    #   @option options [Float] :temperature Temperature setting
    #   @option options [String] :system_message Optional system message
    #   @option options [Array<Hash>] :media Array of media attachments (images, documents)
    # @return [Hash] Result with content and metadata
    def run(prompt, options = {})
      return rate_limit_error_response if prompt.present? && exceeds_rate_limit?(prompt)

      result, latency_ms = with_timing { call_api(prompt, options) }
      build_response(result, latency_ms)
    rescue => e
      handle_error(e)
    end

    # @return [Boolean] True - Anthropic Claude supports multimodal input
    def supports_media?
      true
    end

    # @return [Array<String>] Supported MIME types for media attachments
    def supported_media_types
      SUPPORTED_MEDIA_TYPES
    end

    protected

    def api_key
      Rails.application.credentials.dig(:anthropic, :api_key)
    end

    def default_model
      "claude-sonnet-4-20250514"
    end

    private

    # Checks rate limit and waits or returns error
    def exceeds_rate_limit?(prompt)
      estimated_tokens = estimate_tokens(prompt.to_s)

      unless rate_limiter.can_send_tokens?(estimated_tokens)
        wait_time = rate_limiter.wait_time_for_tokens(estimated_tokens)
        if wait_time > 0
          Rails.logger.warn("Anthropic rate limit: waiting #{wait_time}s")
          sleep(wait_time)
          return false
        end
        @rate_limit_tokens = estimated_tokens
        return true
      end
      false
    end

    def rate_limit_error_response
      error_response(
        error: "Request would exceed token rate limit",
        latency_ms: 0,
        error_type: "rate_limit",
        rate_limit: true
      )
    end

    # Makes the actual API call
    def call_api(prompt, options)
      @last_provider_request = build_params(prompt, options)
      @last_provider_endpoint =
        if Setting.helicone_enabled?
          Rails.application.credentials.dig(:helicone, :base_url)
        else
          nil
        end

      if  Setting.helicone_enabled?
        client = Anthropic::Client.new(
          api_key: Rails.application.credentials.dig(:helicone, :api_key),
          base_url: Rails.application.credentials.dig(:helicone, :base_url)
        )
      else
        client = Anthropic::Client.new(api_key: api_key)
      end
      stream = client.messages.stream(**@last_provider_request)

      message = stream.accumulated_message
      message_hash = message.respond_to?(:to_h) ? message.to_h : message
      parsed = parse_message(message)
      # Use SDK-provided text accumulator as the most reliable source of assistant text.
      content = stream.accumulated_text.to_s
      content = parsed[:content] if content.blank?

      record_token_usage(message)

      message_id = message&.id.to_s
      message_id = "unknown" if message_id.blank?
      parsed = {
        raw_response: message_hash,
        content: content,
        tool_calls: parsed[:tool_calls],
        content_blocks: parsed[:content_blocks],
        message_id: message_id,
        provider_request: @last_provider_request,
        provider_response: message_hash.is_a?(Hash) ? message_hash : message_hash.to_s,
        provider_endpoint: @last_provider_endpoint,
        input_tokens: message&.usage&.input_tokens,
        output_tokens: message&.usage&.output_tokens
      }

      contract = Assistant::Contracts::ProviderResultContracts::Anthropic.call(parsed)
      unless contract.success?
        notify_error(RuntimeError.new("Anthropic provider contract failed"), operation: "call_api", error_type: "contract_failed", contract_errors: contract.errors.to_h)
      end

      parsed
    end

    def build_params(prompt, options)
      params = {
        model: model_name,
        max_tokens: options[:max_tokens] || max_tokens_config,
        temperature: options[:temperature] || temperature_config,
        messages: build_messages(prompt, options)
      }

      params[:system] = options[:system_message] if options[:system_message].present?
      params[:tools] = options[:tools] if options[:tools].present?
      params[:tool_choice] = options[:tool_choice] if options.key?(:tool_choice)
      params
    end

    def build_messages(prompt, options)
      # If caller provides pre-built messages, use them directly
      if options[:messages].present?
        messages = Array(options[:messages])
        # Attach media to the last user message if media is provided
        if options[:media].present?
          return inject_media_into_messages(messages, options[:media])
        end
        return messages
      end

      # Build simple user message with optional media
      content = build_content_with_media(prompt, options[:media])
      [ { role: "user", content: content } ]
    end

    # Builds content array with text and optional media blocks
    #
    # @param text [String] The text content
    # @param media [Array<Hash>, nil] Optional media attachments
    # @return [String, Array<Hash>] String if no media, Array of content blocks otherwise
    def build_content_with_media(text, media)
      return text.to_s if media.blank?

      content_blocks = []

      # Add media blocks first (images/documents)
      Array(media).each do |m|
        block = build_media_block(m)
        content_blocks << block if block
      end

      # Add text block
      content_blocks << { type: "text", text: text.to_s } if text.present?

      content_blocks
    end

    # Builds a single media content block for Anthropic's API
    #
    # @param media [Hash] Media attachment info
    #   - :type [String] "image" or "document"
    #   - :source_type [String] "base64" or "url"
    #   - :media_type [String] MIME type
    #   - :data [String] Base64 data (if source_type is "base64")
    #   - :url [String] URL (if source_type is "url")
    # @return [Hash, nil] Content block for Anthropic API or nil if invalid
    def build_media_block(media)
      media = media.symbolize_keys
      media_type = media[:media_type].to_s

      return nil unless SUPPORTED_MEDIA_TYPES.include?(media_type)

      if media[:type].to_s == "document" || SUPPORTED_DOCUMENT_TYPES.include?(media_type)
        build_document_block(media)
      else
        build_image_block(media)
      end
    end

    # Builds an image content block
    def build_image_block(media)
      source = if media[:source_type].to_s == "url" && media[:url].present?
        { type: "url", url: media[:url] }
      elsif media[:data].present?
        { type: "base64", media_type: media[:media_type], data: media[:data] }
      end

      return nil unless source

      { type: "image", source: source }
    end

    # Builds a document content block (PDF native, DOCX via text extraction)
    def build_document_block(media)
      media_type = media[:media_type].to_s

      # DOCX requires text extraction since Claude doesn't natively support it
      if TEXT_EXTRACTION_TYPES.include?(media_type)
        return build_text_block_from_document(media)
      end

      # Native document support (PDF)
      source = if media[:source_type].to_s == "url" && media[:url].present?
        { type: "url", url: media[:url] }
      elsif media[:data].present?
        { type: "base64", media_type: media[:media_type], data: media[:data] }
      end

      return nil unless source

      {
        type: "document",
        source: source,
        cache_control: media[:cache_control] # Optional caching hint
      }.compact
    end

    # Extracts text from a DOCX file and returns it as a text block
    #
    # @param media [Hash] Media attachment with :data (base64) or :text (pre-extracted)
    # @return [Hash, nil] Text content block or nil
    def build_text_block_from_document(media)
      # If text was pre-extracted, use it directly
      if media[:extracted_text].present?
        return { type: "text", text: format_document_text(media[:extracted_text], media[:filename]) }
      end

      # If we have base64 data, try to extract text from DOCX
      if media[:data].present? && media[:media_type] == "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        extracted = extract_text_from_docx(media[:data])
        if extracted.present?
          return { type: "text", text: format_document_text(extracted, media[:filename]) }
        end
      end

      nil
    end

    # Extracts text from a base64-encoded DOCX file
    #
    # @param base64_data [String] Base64-encoded DOCX content
    # @return [String, nil] Extracted text or nil if extraction fails
    def extract_text_from_docx(base64_data)
      require "docx"
      require "base64"
      require "tempfile"

      Tempfile.create([ "document", ".docx" ]) do |temp|
        temp.binmode
        temp.write(Base64.decode64(base64_data))
        temp.rewind

        doc = Docx::Document.open(temp.path)
        paragraphs = doc.paragraphs.map(&:text).reject(&:blank?)
        paragraphs.join("\n\n")
      end
    rescue LoadError => e
      Rails.logger.warn("DOCX extraction unavailable: #{e.message}. Install 'docx' gem for DOCX support.")
      nil
    rescue => e
      Rails.logger.error("Failed to extract text from DOCX: #{e.message}")
      nil
    end

    # Formats extracted document text with context
    def format_document_text(text, filename = nil)
      header = filename.present? ? "--- Document: #{filename} ---\n\n" : "--- Document Content ---\n\n"
      "#{header}#{text}\n\n--- End of Document ---"
    end

    # Injects media into the last user message in a messages array
    #
    # @param messages [Array<Hash>] Existing messages
    # @param media [Array<Hash>] Media to inject
    # @return [Array<Hash>] Messages with media injected
    def inject_media_into_messages(messages, media)
      return messages if media.blank?

      # Find the last user message
      last_user_idx = messages.rindex { |m| m[:role] == "user" || m["role"] == "user" }
      return messages unless last_user_idx

      messages = messages.deep_dup
      last_msg = messages[last_user_idx]
      existing_content = last_msg[:content] || last_msg["content"]

      # Convert string content to content blocks
      if existing_content.is_a?(String)
        new_content = build_content_with_media(existing_content, media)
      elsif existing_content.is_a?(Array)
        # Already an array of content blocks, prepend media
        media_blocks = Array(media).filter_map { |m| build_media_block(m) }
        new_content = media_blocks + existing_content
      else
        new_content = build_content_with_media("", media)
      end

      messages[last_user_idx] = last_msg.merge(content: new_content)
      messages
    end

    def parse_message(message)
      message_hash = message.respond_to?(:to_h) ? message.to_h : message
      blocks = message_hash.is_a?(Hash) ? (message_hash["content"] || message_hash[:content]) : message&.content
      return { content: "", tool_calls: [] } unless blocks.is_a?(Array)

      text_parts = []
      tool_calls = []
      content_blocks = []

      blocks.each do |b|
        h =
          if b.is_a?(Hash)
            b
          elsif b.respond_to?(:to_h)
            b.to_h
          else
            # Best-effort for SDK objects
            {
              type: (b.respond_to?(:type) ? b.type : nil),
              text: (b.respond_to?(:text) ? b.text : nil),
              id: (b.respond_to?(:id) ? b.id : nil),
              name: (b.respond_to?(:name) ? b.name : nil),
              input: (b.respond_to?(:input) ? b.input : nil)
            }.compact
          end
        next unless h.is_a?(Hash)

        type = (h["type"] || h[:type]).to_s
        case type
        when "text"
          text_parts << (h["text"] || h[:text]).to_s
        when "output_text"
          text_parts << (h["text"] || h[:text]).to_s
        when "tool_use"
          raw_input = h["input"] || h[:input] || {}
          parsed_input =
            if raw_input.is_a?(String)
              begin
                JSON.parse(raw_input)
              rescue JSON::ParserError
                Rails.logger.warn("[AnthropicProvider] Failed to parse tool_use.input JSON; defaulting to {} input=#{raw_input.to_s[0, 200].inspect}")
                {}
              end
            else
              raw_input
            end

          # Ensure stored content blocks match Anthropic's expected shape.
          # Anthropic requires tool_use.input to be an object (dictionary). Some SDK versions
          # surface it as a JSON string; normalize it here so future follow-ups can safely
          # replay provider_content_blocks without 400s.
          parsed_input = {} unless parsed_input.is_a?(Hash)
          h["input"] = parsed_input if h.key?("input") || h.key?("input".to_sym)
          h[:input] = parsed_input if h.key?(:input)

          tool_calls << {
            id: h["id"] || h[:id],
            tool_key: h["name"] || h[:name],
            args: parsed_input
          }
        else
          # Best-effort: if this block contains a text payload, capture it.
          text = h["text"] || h[:text]
          text_parts << text.to_s if text.is_a?(String) && text.present?
        end

        # Store a sanitized version for safe replay during follow-ups (no SDK internals like _json_buf).
        content_blocks << sanitize_anthropic_content_block(h)
      end

      { content: text_parts.join, tool_calls: tool_calls, content_blocks: content_blocks }
    end

    # Anthropic is strict about content blocks: tool_use blocks cannot include extra keys.
    # Keep only the allowed/documented fields so replays don't 400.
    #
    # @param h [Hash]
    # @return [Hash]
    def sanitize_anthropic_content_block(h)
      type = (h["type"] || h[:type]).to_s

      case type
      when "tool_use"
        input = h["input"] || h[:input]
        input = {} unless input.is_a?(Hash)
        {
          "type" => "tool_use",
          "id" => (h["id"] || h[:id]).to_s.presence,
          "name" => (h["name"] || h[:name]).to_s.presence,
          "input" => input
        }.compact
      when "text", "output_text"
        { "type" => "text", "text" => (h["text"] || h[:text]).to_s }
      else
        text = h["text"] || h[:text]
        out = { "type" => type.presence || "text" }
        out["text"] = text.to_s if text.is_a?(String) && text.present?
        out
      end
    rescue StandardError
      { "type" => "text", "text" => "" }
    end

    def build_response(result, latency_ms)
      success_response(
        content: result[:content],
        latency_ms: latency_ms,
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens],
        provider_request: result[:provider_request],
        provider_response: result[:provider_response],
        provider_endpoint: result[:provider_endpoint]
      ).merge(
        tool_calls: result[:tool_calls],
        content_blocks: result[:content_blocks],
        message_id: result[:message_id]
      )
    end

    def handle_error(exception)
      latency_ms = 0 # Error occurred, timing not meaningful

      if rate_limit_error?(exception)
        handle_rate_limit_error(exception, latency_ms)
      else
        handle_general_error(exception, latency_ms)
      end
    end

    def handle_rate_limit_error(exception, latency_ms)
      Rails.logger.warn("Anthropic rate limit exceeded: #{exception.message}")
      retry_after = extract_retry_after(exception)
      http_status = extract_http_status(exception)
      error_response_hash = extract_error_response_hash(exception)

      notify_error(exception, operation: "run", error_type: "rate_limit_exceeded", retry_after: retry_after, http_status: http_status)

      error_response(
        error: "Rate limit exceeded: #{exception.message}",
        latency_ms: latency_ms,
        error_type: "rate_limit",
        rate_limit: true,
        retry_after: retry_after,
        provider_request: @last_provider_request,
        provider_error_response: error_response_hash,
        http_status: http_status,
        response_headers: error_response_hash&.dig(:headers),
        provider_endpoint: @last_provider_endpoint
      )
    end

    def handle_general_error(exception, latency_ms)
      Rails.logger.error("Anthropic request failed: #{exception.message}")

      http_status = extract_http_status(exception)
      error_response_hash = extract_error_response_hash(exception)
      notify_error(exception, operation: "run", error_type: "request_failed", http_status: http_status)

      error_response(
        error: exception.message,
        latency_ms: latency_ms,
        error_type: exception.class.name,
        provider_request: @last_provider_request,
        provider_error_response: error_response_hash,
        http_status: http_status,
        response_headers: error_response_hash&.dig(:headers),
        provider_endpoint: @last_provider_endpoint
      )
    end

    # Rate limiting helpers

    def rate_limiter
      @rate_limiter ||= Scraping::AnthropicRateLimiterService.new
    end

    def record_token_usage(message)
      input_tokens = message&.usage&.input_tokens
      rate_limiter.record_tokens_used(input_tokens) if input_tokens
    end

    def estimate_tokens(text)
      (text.length.to_f / 3.0).ceil
    end

    def rate_limit_error?(error)
      message = error.message.to_s.downcase
      return true if message.include?("rate_limit") || message.include?("rate limit") || message.include?("429")
      return true if error.respond_to?(:status) && error.status == 429
      check_response_for_rate_limit(error)
    end

    def check_response_for_rate_limit(error)
      return false unless error.respond_to?(:response)

      response = error.response
      return false unless response.is_a?(Hash)
      return true if response[:status] == 429 || response["status"] == 429

      error_type = response.dig(:body, :error, :type) || response.dig("body", "error", "type")
      error_type&.downcase&.include?("rate_limit") || false
    end

    def extract_retry_after(error)
      return nil unless error.respond_to?(:response)

      headers = error.response&.dig(:headers) || error.response&.dig("headers") || {}
      retry_after = headers["retry-after"] || headers[:retry_after] || headers["Retry-After"]
      retry_after&.to_i
    rescue
      nil
    end

    def extract_http_status(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      return response[:status] || response["status"] if response.is_a?(Hash)

      nil
    rescue StandardError
      nil
    end

    def extract_response_body(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      return response[:body] || response["body"] if response.is_a?(Hash)

      nil
    rescue StandardError
      nil
    end

    def extract_response_headers(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      return response[:headers] || response["headers"] if response.is_a?(Hash)

      nil
    rescue StandardError
      nil
    end

    def extract_error_response_hash(exception)
      http_status = extract_http_status(exception)
      body = extract_response_body(exception)
      headers = extract_response_headers(exception)
      return nil if http_status.blank? && body.blank? && headers.blank?

      {
        status: http_status,
        headers: headers,
        body: body
      }.compact
    end
  end
end
