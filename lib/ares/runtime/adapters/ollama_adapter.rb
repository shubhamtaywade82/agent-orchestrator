# frozen_string_literal: true

module Ares
  module Runtime
    class OllamaAdapter
      def initialize
        config_data = ConfigManager.load_ollama
        config = Ollama::Config.new
        config.base_url = config_data[:base_url]
        config.timeout = config_data[:timeout]
        config.num_ctx = config_data[:num_ctx]
        config.retries = config_data[:retries]

        @client = Ollama::Client.new(config: config)
      end

      def call(prompt, model = nil, schema: nil)
        model ||= best_available_model

        options = { prompt: prompt, model: model }
        options[:schema] = schema if schema

        @client.generate(**options)
      end

      private

      def best_available_model
        available = @client.list_model_names
        return 'qwen3:latest' if available.include?('qwen3:latest')
        return 'qwen3:8b' if available.include?('qwen3:8b')

        available.first || 'qwen3:8b' # Fallback
      end
    end
  end
end
