# frozen_string_literal: true

require 'yaml'
require_relative 'config_manager'

class ModelSelector
  CONFIDENCE_THRESHOLD = 0.7

  def self.select(plan)
    @config = Ares::Runtime::ConfigManager.load_models

    task_type = plan['task_type']
    confidence = plan['confidence'] || 1.0

    # Escalate if confidence is low or risk is explicitly high
    return { engine: :claude, model: 'opus' } if confidence < CONFIDENCE_THRESHOLD || plan['risk_level'] == 'high'

    # Use string key lookup as ConfigManager returns keys as strings sometimes
    rule = @config[task_type.to_sym] || @config[:refactor]

    {
      engine: rule[:engine].to_sym,
      model: rule[:model]
    }
  end
end
