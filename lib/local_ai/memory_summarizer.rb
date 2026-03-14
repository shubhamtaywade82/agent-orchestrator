# frozen_string_literal: true

module Ares
  module LocalAI
    class MemorySummarizer
      def initialize(client: nil)
        @client = client || OllamaClient.new
      end

      def summarize(entries)
        return "" if entries.nil? || entries.empty?

        text = entries.map { |e| "#{e[:type]}: #{e[:payload]}" }.join("\n")
        prompt = <<~PROMPT
          Compress this task history into a short summary (2-4 sentences) for context.

          #{text.lines.first(50).join}
        PROMPT
        @client.generate(prompt).to_s.strip
      end
    end
  end
end
