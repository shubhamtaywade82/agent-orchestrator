# frozen_string_literal: true

require 'ollama_client'
require 'timeout'
require_relative '../../../../config/planner_schema'
require_relative '../ollama_client_factory'

module Ares
  module Runtime
    class OllamaPlanner
      PLANNER_TIMEOUT = 30 # Longer once health is verified
      HARD_TIMEOUT = 35

      def initialize(healthy: true)
        @healthy = healthy
        @client = healthy ? OllamaClientFactory.build(timeout_seconds: PLANNER_TIMEOUT) : nil
      end

      def plan(task)
        return safe_default_plan(task) unless @healthy

        OllamaClientFactory.with_resilience(
          hard_timeout: HARD_TIMEOUT,
          fallback_value: safe_default_plan(task)
        ) do
          @client.generate(prompt: build_prompt(task), schema: PLANNER_SCHEMA)
        end
      end

      private

      def safe_default_plan(task)
        {
          'task_type' => 'refactor',
          'risk_level' => 'medium',
          'confidence' => 1.0,
          'slices' => [task],
          'explanation' => 'Safe Mode Default: Proceeding with high-level refactor plan.'
        }
      end

      def build_prompt(task)
        PromptBuilder.new
                     .add_instruction("Analyze the following engineering task.\nDecompose it into discrete, executable work units (slices).\nAssign a task type, risk level, and confidence score.")
                     .add_task(task)
                     .add_instruction('Respond strictly as JSON. Slices should be a clean array of strings.')
                     .build
      end
    end
  end
end
