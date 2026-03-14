# frozen_string_literal: true

require "json"

module Ares
  module LocalAI
    class TaskClassifier
      TASK_TYPES = %w[architecture code_generation repo_analysis file_edit summarization].freeze

      def initialize(client: nil)
        @client = client || OllamaClient.new
      end

      def classify(task_string)
        prompt = <<~PROMPT
          Classify this development task. Reply with JSON only: {"task_type": "...", "preferred_model": "..."}
          task_type must be one of: #{TASK_TYPES.join(", ")}.
          preferred_model: claude, codex, gemini, cursor, or local.

          Task: #{task_string}
        PROMPT
        response = @client.generate(prompt)
        parse(response, task_string)
      end

      private

      def parse(response, task_string)
        json = extract_json(response)
        return fallback(task_string) if json.nil?

        {
          task_type: (json["task_type"] || "architecture").to_sym,
          preferred_model: (json["preferred_model"] || "claude").to_sym
        }
      rescue JSON::ParserError
        fallback(task_string)
      end

      def extract_json(text)
        return nil if text.nil? || text.empty?

        start = text.index("{")
        return nil unless start

        brace = 0
        i = start
        while i < text.size
          c = text[i]
          brace += 1 if c == "{"
          brace -= 1 if c == "}"
          return JSON.parse(text[start..i]) if brace == 0

          i += 1
        end
        nil
      end

      def fallback(task_string)
        { task_type: :architecture, preferred_model: :claude }
      end
    end
  end
end
