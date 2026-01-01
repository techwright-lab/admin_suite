# frozen_string_literal: true

require "dry/schema"

module Assistant
  module Contracts
    # Runtime contracts for provider adapter outputs.
    #
    # These validate the adapter boundary so malformed provider responses become explicit errors
    # (instead of leaking as nils/odd hashes into the rest of the assistant pipeline).
    module ProviderResultContracts
      Openai = Dry::Schema.Params do
        required(:raw_response).value(:any)
        required(:content).value(:string)
        required(:tool_calls).array(:hash)
        required(:response_id).filled(:string)
        optional(:input_tokens).maybe(:integer)
        optional(:output_tokens).maybe(:integer)
      end

      Anthropic = Dry::Schema.Params do
        required(:raw_response).value(:any)
        required(:content).value(:string)
        required(:tool_calls).array(:hash)
        required(:content_blocks).array(:hash)
        required(:message_id).filled(:string)
        optional(:input_tokens).maybe(:integer)
        optional(:output_tokens).maybe(:integer)
      end
    end
  end
end
