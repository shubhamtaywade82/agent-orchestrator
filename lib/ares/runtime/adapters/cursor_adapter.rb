# frozen_string_literal: true

require 'open3'
require 'timeout'

module Ares
  module Runtime
    # Adapter for Cursor CLI (agent). Uses stdin piping and trust flags for automation.
    class CursorAdapter
      ADAPTER_TIMEOUT = 30

      def call(prompt, _model = nil, resume: true, cloud: false)
        cmd = build_command(resume, cloud)
        output, status = execute_with_timeout(cmd, prompt)

        if !status.success? && output.include?('No previous chats found')
          # Retry without resume if it's a fresh session
          cmd = build_command(false, cloud)
          output, status = execute_with_timeout(cmd, prompt)
        end

        raise "Cursor command failed: #{output}" unless status.success?

        output
      end

      private

      def execute_with_timeout(cmd, prompt)
        Timeout.timeout(ADAPTER_TIMEOUT) do
          Open3.capture2e(*cmd, stdin_data: prompt)
        end
      rescue Timeout::Error => e
        raise "Cursor command timed out after #{ADAPTER_TIMEOUT}s: #{e.message}"
      end

      def build_command(resume, cloud)
        # --trust --yolo ensures no interactive prompts in headless mode
        cmd = ['agent', '-p', '-', '--trust', '--yolo']
        cmd << '-c' if cloud
        cmd << '--continue' if resume && !cloud
        cmd
      end
    end
  end
end
