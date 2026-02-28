# frozen_string_literal: true

module Ares
  module Runtime
    class ModelSelector
      CONFIDENCE_THRESHOLD = 0.7

      def self.select(plan)
        @config = ConfigManager.load_models

        task_type = plan['task_type']
        confidence = plan['confidence'] || 1.0

        # Escalate if confidence is low or risk is explicitly high
        return { engine: :claude, model: 'opus' } if confidence < CONFIDENCE_THRESHOLD || plan['risk_level'] == 'high'

        # Use string key lookup as ConfigManager returns keys as strings sometimes
        rule = @config[task_type.to_sym] || @config[:refactor]
        engine = rule[:engine].to_sym

        # Safety: restrict Ollama from code-modifying tasks if configured incorrectly
        if engine == :ollama && %w[refactor architecture bulk_patch test_generation].include?(task_type.to_s)
          engine = :claude
          model = 'sonnet'
        else
          model = rule[:model]
        end

        {
          engine: engine,
          model: model
        }
      end
    end
  end
end
