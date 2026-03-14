# frozen_string_literal: true

module Ares
  module LocalAI
    class Summarizer
      def summarize(text)
        client = OllamaClient.new
        client.generate("Summarize briefly:\n\n#{text}")
      end
    end
  end
end
