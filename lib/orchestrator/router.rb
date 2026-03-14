# frozen_string_literal: true

module Ares
  module Orchestrator
    class Router
      def route(task)
        case task.type
        when :architecture
          Agents::ClaudeAgent
        when :code_generation
          Agents::CodexAgent
        else
          nil
        end
      end
    end
  end
end
