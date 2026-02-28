# frozen_string_literal: true

require_relative 'base_adapter'

module Ares
  module Runtime
    # Adapter for Claude CLI. Passes prompts via stdin to avoid ARG_MAX limits.
    class ClaudeAdapter < BaseAdapter
      def call(prompt, model = nil, fork_session: false, **_options)
        check_auth!
        super(prompt, model, fork_session: fork_session)
      end

      protected

      def build_command(_prompt, model, fork_session: false, **_options)
        model ||= 'sonnet'
        # -p - means read prompt from stdin
        # --allow-dangerously-skip-permissions bypasses interactive prompts
        cmd = ['claude', '--model', model, '-p', '-', '--allow-dangerously-skip-permissions']
        cmd += %w[--continue --fork-session] if fork_session
        cmd
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
