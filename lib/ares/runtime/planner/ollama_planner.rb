# frozen_string_literal: true

require 'ollama_client'
require_relative '../../../../config/planner_schema'
module Ares
  module Runtime
    class OllamaPlanner
      def initialize
        config_data = ConfigManager.load_ollama
        config = Ollama::Config.new
        config.base_url = config_data[:base_url]
        config.timeout = 5 # Strict 5s timeout for local planning
        config.num_ctx = config_data[:num_ctx]
        @client = Ollama::Client.new(config: config)
      end

      def plan(task)
        @client.generate(
          prompt: build_prompt(task),
          schema: PLANNER_SCHEMA
        )
      rescue StandardError => e
        # Safe Mode Fallback: Return a default high-level plan if Ollama is down
        {
          'task_type' => 'refactor',
          'risk_level' => 'medium',
          'confidence' => 1.0,
          'slices' => [task],
          'explanation' => "Safe Mode: Ollama unavailable (#{e.message.split("\n").first}). Proceeding with default refactor plan."
        }
      end

      private

      def build_prompt(task)
        <<~PROMPT
          Analyze the following engineering task.
          Decompose it into discrete, executable work units (slices).
          Assign a task type, risk level, and confidence score.

          TASK:
          #{task}

          Respond strictly as JSON. Slices should be a clean array of strings.
        PROMPT
      end
    end
  end
end
