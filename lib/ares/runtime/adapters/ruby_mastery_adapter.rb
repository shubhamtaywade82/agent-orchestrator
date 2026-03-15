# frozen_string_literal: true

require_relative 'claude_adapter'

module Ares
  module Runtime
    # Wraps ClaudeAdapter with a Ruby-expert system prompt. Used when engine is :ruby_mastery.
    class RubyMasteryAdapter < ClaudeAdapter
      SYSTEM_PROMPT = <<~PROMPT.freeze
        You are a Ruby expert. Apply idiomatic Ruby: blocks, enumerables, symbols, minimal syntax.
        Follow SOLID and the Ruby style guide (rubystyle.guide). Prefer clarity over cleverness.
        When fixing diagnostics, respond only with valid JSON: {"explanation": "...", "patches": [{"file": "path", "content": "full content"}]}.
      PROMPT

      def call(prompt, model = nil, **options)
        full_prompt = "#{SYSTEM_PROMPT}\n\n#{prompt}"
        super(full_prompt, model, **options)
      end
    end
  end
end
