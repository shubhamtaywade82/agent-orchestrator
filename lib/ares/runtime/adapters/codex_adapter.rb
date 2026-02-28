# frozen_string_literal: true

require_relative 'base_adapter'

module Ares
  module Runtime
    # Adapter for OpenAI Codex CLI. Uses exec mode with full automation for headless environments.
    class CodexAdapter < BaseAdapter
      def call(prompt, model = nil, resume: true, **_options)
        super(prompt, model, resume: resume)
      end

      def apply_cloud_task(task_id)
        cmd = ['codex', 'apply', task_id]
        Ares::Runtime::TerminalRunner.run(cmd)
      end

      protected

      def build_command(_prompt, _model, resume: true, **_options)
        cmd = ['codex', 'exec', '--full-auto', '-']
        cmd << '--resume' if resume
        cmd
      end

      def should_retry?(status, output)
        !status.success? && (output.include?('No session found') || output.include?('error: unexpected argument'))
      end

      def build_retry_command(cmd, _prompt, **_options)
        cmd.dup.tap { |c| c.delete('--resume') }
      end
    end
  end
end
