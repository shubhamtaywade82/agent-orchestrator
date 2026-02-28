# frozen_string_literal: true

require 'ollama_client'
require_relative '../../config/planner_schema'

class OllamaPlanner
  def initialize
    @client = Ollama::Client.new
  end

  def plan(task)
    @client.generate(
      prompt: build_prompt(task),
      schema: PLANNER_SCHEMA
    )
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
