# frozen_string_literal: true

require 'open3'

module Ares
  module Runtime
    # Adapter for OpenAI Codex CLI. Uses exec mode with full automation for headless environments.
    class CodexAdapter
      def call(prompt, _model = nil, resume: true)
        # Use codex exec for non-interactive mode.
        # --full-auto is the correct flag for low-friction automation.
        cmd = ['codex', 'exec', '--full-auto', '-']
        cmd << '--resume' if resume

        output, status = Open3.capture2e(*cmd, stdin_data: prompt)

        output, status = retry_without_resume(cmd, prompt) if should_retry?(status, output)

        raise "Codex command failed: #{output}" unless status.success?

        output
      end

      def apply_cloud_task(task_id)
        cmd = ['codex', 'apply', task_id]
        Ares::Runtime::TerminalRunner.run(cmd)
      end

      private

      def should_retry?(status, output)
        !status.success? && (output.include?('No session found') || output.include?('error: unexpected argument'))
      end

      def retry_without_resume(cmd, prompt)
        cmd.delete('--resume')
        Open3.capture2e(*cmd, stdin_data: prompt)
      end
    end
  end
end
