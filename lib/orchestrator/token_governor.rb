# frozen_string_literal: true

module Ares
  module Orchestrator
    class TokenGovernor
      DEFAULT_LIMITS = {
        claude: 100_000,
        codex: 50_000,
        gemini: 100_000,
        cursor: 200_000,
        local: 500_000
      }.freeze

      FALLBACKS = {
        claude: :gemini,
        gemini: :claude,
        codex: :codex
      }.freeze

      def initialize(limits: nil, fallbacks: nil)
        @usage = Hash.new(0)
        @limits = limits || DEFAULT_LIMITS
        @fallbacks = fallbacks || FALLBACKS
      end

      def increment(model, tokens)
        @usage[model.to_sym] += tokens
      end

      def usage(model)
        @usage[model.to_sym] || 0
      end

      def over_threshold?(model, limit = nil)
        cap = limit || @limits[model.to_sym]
        return false if cap.nil? || cap <= 0

        usage(model) >= cap
      end

      def switch_model(model)
        @fallbacks[model.to_sym] || model
      end
    end
  end
end
