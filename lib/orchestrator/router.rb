# frozen_string_literal: true

module Ares
  module Orchestrator
    class Router
      TYPE_TO_MODEL = {
        architecture: :claude,
        code_generation: :codex,
        repo_analysis: :gemini,
        file_edit: :cursor,
        summarization: :local
      }.freeze

      MODEL_TO_AGENT = {
        claude: Ares::Agents::ClaudeAgent,
        codex: Ares::Agents::CodexAgent,
        gemini: Ares::Agents::GeminiAgent,
        cursor: Ares::Agents::CursorAgent,
        local: :local
      }.freeze

      def initialize(token_governor: nil)
        @governor = token_governor
      end

      def route(task)
        model = TYPE_TO_MODEL[task.type] || :claude
        model = @governor.switch_model(model) if @governor&.over_threshold?(model)

        agent = MODEL_TO_AGENT[model]
        agent == :local ? :local : agent
      end
    end
  end
end
