# frozen_string_literal: true

module Ai
  # Service for parsing LLM responses into JSON data.
  #
  # Supports extracting JSON blocks embedded in text and optional symbolization.
  #
  # @example
  #   parsed = Ai::ResponseParserService.new(response_text).parse(symbolize: true)
  class ResponseParserService
    # @param response_text [String] Raw LLM response
    # @param json_only [Boolean] If true, only parse JSON block
    def initialize(response_text, json_only: true)
      @response_text = response_text.to_s
      @json_only = json_only
    end

    # Parses the response into a Hash.
    #
    # @param symbolize [Boolean] Whether to symbolize keys
    # @return [Hash, nil]
    def parse(symbolize: false)
      return nil if response_text.blank?

      payload = json_only ? extract_json(response_text) : response_text
      return nil if payload.blank?

      JSON.parse(payload, symbolize_names: symbolize)
    rescue JSON::ParserError
      nil
    end

    private

    attr_reader :response_text, :json_only

    def extract_json(text)
      match = text.match(/\{.*\}/m)
      match&.[](0)
    end
  end
end
