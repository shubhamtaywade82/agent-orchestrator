# frozen_string_literal: true

module Ares
  module LocalAI
    class GuardrailValidator
      SENSITIVE_PATTERNS = [
        /api[_-]?key\s*[:=]/i,
        /password\s*[:=]/i,
        /secret\s*[:=]/i,
        /bearer\s+[a-z0-9._-]+/i
      ].freeze

      DEFAULT_MAX_CHARS = 100_000

      def initialize(max_chars: DEFAULT_MAX_CHARS)
        @max_chars = max_chars
      end

      def valid?(prompt_or_task)
        return false if prompt_or_task.nil?

        text = prompt_or_task.to_s
        return false if text.size > @max_chars
        return false if sensitive?(text)

        true
      end

      def sensitive?(text)
        SENSITIVE_PATTERNS.any? { |re| text.match?(re) }
      end

      def oversized?(text)
        text.to_s.size > @max_chars
      end
    end
  end
end
