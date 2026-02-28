# frozen_string_literal: true

require_relative 'task_logger'
require_relative 'planner/ollama_planner'
require_relative 'planner/tiny_task_processor'
require_relative 'ollama_client_factory'

module Ares
  module Runtime
    # Subsystem Facade that initializes and bundles core dependencies for the Router.
    class CoreSubsystem
      attr_reader :logger, :planner, :selector, :tiny_processor, :ollama_healthy

      def initialize
        @logger = TaskLogger.new
        @ollama_healthy = initialize_ollama

        @planner = OllamaPlanner.new(healthy: @ollama_healthy)
        @selector = ModelSelector.new
        @tiny_processor = TinyTaskProcessor.new(healthy: @ollama_healthy)
      end

      private

      def initialize_ollama
        healthy = OllamaClientFactory.health_check?
        if healthy
          puts "✅ Local AI Engine (Ollama) is available."
        else
          puts "⚠️ Local AI (Ollama) unavailable. Running in Safe Mode for planning/diagnostics."
        end
        healthy
      end
    end
  end
end
