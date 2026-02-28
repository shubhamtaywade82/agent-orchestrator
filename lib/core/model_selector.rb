require "yaml"

class ModelSelector
  CONFIDENCE_THRESHOLD = 0.7
  CONFIG_PATH = File.expand_path("../../config/models.yml", __dir__)

  def self.select(plan)
<<<<<<< Updated upstream
    @config ||= YAML.load_file(CONFIG_PATH)
=======
    @config = YAML.load_file(CONFIG_PATH)
>>>>>>> Stashed changes

    task_type = plan["task_type"]
    confidence = plan["confidence"] || 1.0

    # Escalate if confidence is low or risk is explicitly high
    if confidence < CONFIDENCE_THRESHOLD || plan["risk_level"] == "high"
      return { engine: :claude, model: "opus" }
    end

    rule = @config[task_type] || @config["refactor"]

    {
      engine: rule["engine"].to_sym,
      model: rule["model"]
    }
  end
end
