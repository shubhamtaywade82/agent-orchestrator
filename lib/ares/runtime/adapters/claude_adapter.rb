# frozen_string_literal: true

require 'open3'

module Ares
  module Runtime
    # Adapter for Claude CLI. Passes prompts via stdin to avoid ARG_MAX limits.
    class ClaudeAdapter
      def call(prompt, model, fork_session: false)
        check_auth!
        model ||= 'sonnet'

        # -p - means read prompt from stdin
        # --allow-dangerously-skip-permissions bypasses interactive prompts
        cmd = ['claude', '--model', model, '-p', '-', '--allow-dangerously-skip-permissions']
        cmd += %w[--continue --fork-session] if fork_session

        output, status = Open3.capture2e(*cmd, stdin_data: prompt)
        raise "Claude command failed: #{output}" unless status.success?

        output
      end

      private

      def check_auth!
        system('claude auth status > /dev/null 2>&1')
        return if $CHILD_STATUS.success?

        raise 'Claude CLI not logged in. Please run `claude login` in your terminal.'
      end
    end
  end
end
