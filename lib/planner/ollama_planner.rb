require 'ollama_client'
require_relative '../../config/planner_schema'

class OllamaPlanner
  def initialize
    @client = Ollama::Client.new
  end

  def plan(task)
    @client.generate(
      prompt: build_prompt(task),
      model: best_available_model,
      schema: PLANNER_SCHEMA
    )
  end

  private

  def best_available_model
    available = @client.list_model_names
    return 'qwen3:latest' if available.include?('qwen3:latest')
    return 'qwen3:8b' if available.include?('qwen3:8b')

    available.first || 'qwen3:8b'
  end

  def build_prompt(task)
    <<~PROMPT
      Analyze the following engineering task.
      Decompose it into discrete, executable work units (slices).
      Assign a task type (e.g., refactor, architecture, diagnostic, test_generation), risk level, and confidence score.

      TASK:
      #{task}

      Respond strictly as JSON. Slices should be a clean array of strings.
    PROMPT
  end
end
