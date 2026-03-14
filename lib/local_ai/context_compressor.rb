# frozen_string_literal: true

module Ares
  module LocalAI
    class ContextCompressor
      def initialize(client: nil)
        @client = client || OllamaClient.new
      end

      def compress_ruby(file_path)
        code = File.read(file_path)
        prompt = <<~PROMPT
          Summarize the structure of this Ruby file. Return only: class name, methods, dependencies, responsibilities (one line). No code.
          #{code.lines.first(100).join}
        PROMPT
        @client.generate(prompt).to_s.strip
      end
    end
  end
end
