# frozen_string_literal: true

module Ares
  module Agents
    # Cursor is the execution engine for file edits.
    # Stub: actual Cursor API / protocol integration out of scope.
    class CursorAgent
      def self.run(task, context: nil)
        path = task.payload.is_a?(Hash) ? task.payload[:path] : nil
        operation = task.payload.is_a?(Hash) ? task.payload[:operation] : task.payload

        return { success: false, error: "missing path or operation" } if path.to_s.empty? && operation.to_s.empty?

        { success: true, path: path, operation: operation, patch: nil }
      end
    end
  end
end
