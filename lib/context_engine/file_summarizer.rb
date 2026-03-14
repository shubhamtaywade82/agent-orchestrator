# frozen_string_literal: true

require "json"

module Ares
  module ContextEngine
    class FileSummarizer
      def initialize(ollama_client: nil)
        @client = ollama_client || LocalAI::OllamaClient.new
      end

      def summarize(file_path, code:, symbols: {})
        prompt = build_prompt(file_path, code, symbols)
        response = @client.generate(prompt)
        parse_response(file_path, response, symbols)
      end

      private

      def build_prompt(file_path, code, symbols)
        <<~PROMPT
          Summarize this Ruby file in one short paragraph.

          File: #{file_path}

          Return JSON only, no markdown:
          {"class": "ClassName", "responsibility": "one line", "methods": ["method1","method2"], "dependencies": ["OtherClass"]}

          Code:
          #{code.lines.first(50).join}
          #{code.lines.size > 50 ? "\n... (#{code.lines.size} lines total)" : ""}
        PROMPT
      end

      def parse_response(file_path, response, symbols)
        json = extract_json(response)
        return fallback_summary(file_path, symbols) if json.nil? || json.empty?

        {
          file: file_path,
          class: json["class"] || symbols[:classes]&.first,
          responsibility: json["responsibility"] || "see code",
          methods: json["methods"] || symbols[:methods] || [],
          dependencies: json["dependencies"] || symbols[:dependencies]&.uniq || []
        }
      rescue JSON::ParserError
        fallback_summary(file_path, symbols)
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

      def fallback_summary(file_path, symbols)
        {
          file: file_path,
          class: symbols[:classes]&.first,
          responsibility: "see code",
          methods: symbols[:methods] || [],
          dependencies: symbols[:dependencies]&.uniq || []
        }
      end
    end
  end
end
