# frozen_string_literal: true

require 'open3'
require 'timeout'

module Ares
  module Runtime
    # Adapter for OpenAI Codex CLI. Uses exec mode with full automation for headless environments.
    class CodexAdapter
      ADAPTER_TIMEOUT = 30

      def call(prompt, _model = nil, resume: true)
        cmd = ['codex', 'exec', '--full-auto', '-']
        cmd << '--resume' if resume

        output, status = execute_with_timeout(cmd, prompt)

        output, status = retry_without_resume(cmd, prompt) if should_retry?(status, output)

        raise "Codex command failed: #{output}" unless status.success?

        output
      end

      def apply_cloud_task(task_id)
        cmd = ['codex', 'apply', task_id]
        Ares::Runtime::TerminalRunner.run(cmd)
      end

      private

      def execute_with_timeout(cmd, prompt)
        Timeout.timeout(ADAPTER_TIMEOUT) do
          Open3.capture2e(*cmd, stdin_data: prompt)
        end
      rescue Timeout::Error => e
        raise "Codex command timed out after #{ADAPTER_TIMEOUT}s: #{e.message}"
      end

      def should_retry?(status, output)
        !status.success? && (output.include?('No session found') || output.include?('error: unexpected argument'))
      end

      def retry_without_resume(cmd, prompt)
        cmd.delete('--resume')
        execute_with_timeout(cmd, prompt)
      end
    end
  end
end
