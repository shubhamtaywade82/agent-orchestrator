# frozen_string_literal: true

require 'open3'

module Ares
  module Runtime
    # Core class for executing terminal commands, with support for sandboxing via Codex.
    # Uses popen2e (single-threaded) to avoid "stream closed in another thread" with TTY/Timeout.
    class TerminalRunner
      def self.run(cmd, stdin_data: nil)
        args = cmd.is_a?(Array) ? cmd : [cmd]
        output, status = Open3.popen2e(*args) do |stdin, outerr, wait_thr|
          stdin.write(stdin_data) if stdin_data
          stdin.close
          [outerr.read, wait_thr.value]
        end

        cmd_str = cmd.is_a?(Array) ? cmd.join(' ') : cmd
        raise "Command failed: #{cmd_str}\nOutput: #{output}" unless status.success?

        { output: output, exit_status: status.exitstatus }
      rescue StandardError => e
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
