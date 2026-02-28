# frozen_string_literal: true

require 'ollama_client'
require 'timeout'
require_relative 'config_manager'

module Ares
  module Runtime
    # Centralizes Ollama client creation with strict timeouts and fail-fast logic.
    class OllamaClientFactory
      def self.build(timeout_seconds: 10)
        config_data = ConfigManager.load_ollama
        config = Ollama::Config.new
        config.base_url = config_data[:base_url]
        config.num_ctx = config_data[:num_ctx]
        config.timeout = timeout_seconds
        config.retries = 0 # Fail fast, let Ares handle fallbacks

        Ollama::Client.new(config: config)
      end

      # 5s strict health check to determine if local AI is available.
      def self.health_check?
        Timeout.timeout(5) do
          client = build(timeout_seconds: 4)
          # 'tags' call is a lightweight way to check connectivity
          client.tags
          true
        end
      rescue StandardError, Timeout::Error
        false
      end

      # Executes an Ollama call with a hard timeout and a provided fallback block.
      def self.with_resilience(hard_timeout: 15, fallback_value: nil, &block)
        Timeout.timeout(hard_timeout, &block)
      rescue StandardError, Timeout::Error => e
        puts "\n⚠️ Local AI (Ollama) Failure: #{e.message.split("\n").first}. Triggering Safe Mode fallback."
        fallback_value
      end
    end
  end
end
