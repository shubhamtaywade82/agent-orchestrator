# frozen_string_literal: true

require_relative 'base_adapter'

module Ares
  module Runtime
    # Adapter for Cursor CLI (agent). Uses stdin piping and trust flags for automation.
    class CursorAdapter < BaseAdapter
      def call(prompt, model = nil, resume: true, cloud: false, **_options)
        super(prompt, model, resume: resume, cloud: cloud)
      end

      protected

      def build_command(prompt, _model, resume: true, cloud: false, **_options)
        # Force strict non-conversational behavior for Cursor Agent
        agent_prompt = "ACT AS AN AUTONOMOUS AGENT. PERFORM THE FOLLOWING TASK. DO NOT CHAT.\nTASK: #{prompt}"
        # --trust --yolo ensures no interactive prompts in headless mode
        cmd = ['agent', agent_prompt, '--print', '--trust', '--yolo']
        cmd << '-c' if cloud
        cmd << '--continue' if resume && !cloud
        cmd
      end


      def pipes_prompt_to_stdin?
        false
      end

      def should_retry?(status, output)
        !status.success? && output.include?('No previous chats found')
      end

      def build_retry_command(cmd, _prompt, **_options)
        cmd.dup.tap { |c| c.delete('--continue') }
      end

      def timeout_seconds
        300 # Increased timeout for complex agent tasks
      end
    end
  end
end
