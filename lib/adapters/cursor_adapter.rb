# frozen_string_literal: true

require 'open3'

module Ares
  module Runtime
    # Adapter for Cursor CLI (agent). Uses stdin piping and trust flags for automation.
    class CursorAdapter
      def call(prompt, _model = nil, resume: true, cloud: false)
        cmd = build_command(resume, cloud)
        output, status = Open3.capture2e(*cmd, stdin_data: prompt)

        if !status.success? && output.include?('No previous chats found')
          cmd.delete('--continue')
          output, status = Open3.capture2e(*cmd, stdin_data: prompt)
        end

        raise "Cursor command failed: #{output}" unless status.success?

        output
      end

      private

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
