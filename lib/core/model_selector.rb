require 'yaml'

class ModelSelector
  CONFIDENCE_THRESHOLD = 0.7
  CONFIG_PATH = File.expand_path('../../config/models.yml', __dir__)

  def self.select(plan)
    YAML.load_file(CONFIG_PATH)

    task_type = plan['task_type']
    confidence = plan['confidence'] || 1.0

    # Escalate if confidence is low or risk is explicitly high
    return { engine: :claude, model: 'opus' } if confidence < CONFIDENCE_THRESHOLD || plan['risk_level'] == 'high'

    rule = @config[task_type] || @config['refactor']

    {
      engine: rule['engine'].to_sym,
      model: rule['model']
    }
  end
end
