# frozen_string_literal: true

module Ares
  module LocalAI
    class DiffSummarizer
      def initialize(client: nil)
        @client = client || OllamaClient.new
      end

      def summarize(diff_text)
        return "" if diff_text.nil? || diff_text.to_s.strip.empty?

        prompt = <<~PROMPT
          Summarize this git diff in 1-3 short sentences. Focus on what changed (files, behavior).

          #{diff_text.lines.first(200).join}
        PROMPT
        @client.generate(prompt).to_s.strip
      end
    end
  end
end
