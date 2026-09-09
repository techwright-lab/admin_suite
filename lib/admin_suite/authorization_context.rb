# frozen_string_literal: true

module AdminSuite
  # Surface-agnostic context handed to `config.authorize`.
  #
  # Replaces the old `controller:` keyword, which could not be honestly
  # populated for a non-HTTP surface. `surface` lets one hook express
  # different policy per entry point -- e.g. reads from anywhere, writes
  # only from the human UI.
  class AuthorizationContext
    SURFACES = %i[web mcp].freeze

    attr_reader :surface, :controller, :request

    def initialize(surface:, controller: nil, request: nil)
      unless SURFACES.include?(surface)
        raise ArgumentError, "Unknown AdminSuite authorization surface #{surface.inspect}. Expected one of #{SURFACES.inspect}."
      end

      @surface = surface
      @controller = controller
      @request = request
    end

    def web? = surface == :web
    def mcp? = surface == :mcp
  end
end
