# frozen_string_literal: true

require 'open3'

module Ares
  module Runtime
    # Core class for executing terminal commands, with support for sandboxing via Codex.
    class TerminalRunner
      def self.run(cmd, stdin_data: nil)
        # Ensure cmd is an array for capture2e if we want to avoid shell injection,
        # but the Router currently passes strings for complex commands.
        # We'll normalize or handle both.
        output, status = if cmd.is_a?(Array)
                           Open3.capture2e(*cmd, stdin_data: stdin_data)
                         else
                           Open3.capture2e(cmd, stdin_data: stdin_data)
                         end

        # Safe join for logging/errors
        cmd_str = cmd.is_a?(Array) ? cmd.join(' ') : cmd
        raise "Command failed: #{cmd_str}\nOutput: #{output}" unless status.success?

        { output: output, exit_status: status.exitstatus }
      rescue StandardError => e
        # Return a hash consistent with the Router's expectations
        { output: e.message, exit_status: 1 }
      end

      def self.run_sandboxed(cmd)
        # Use codex sandbox for secure execution
        cmd_array = cmd.is_a?(Array) ? cmd : [cmd]
        full_cmd = ['codex', 'sandbox', '--full-auto', '--', *cmd_array]
        run(full_cmd)
      end
    end
  end
end
