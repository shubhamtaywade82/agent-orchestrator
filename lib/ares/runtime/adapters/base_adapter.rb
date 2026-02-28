# frozen_string_literal: true

require 'open3'
require 'timeout'

module Ares
  module Runtime
    # Abstract base class implementing the Template Method pattern for CLI adapters.
    # Defines the skeleton for execution, timeouts, and retries.
    class BaseAdapter
      DEFAULT_TIMEOUT = 30

      def call(prompt, model = nil, **options)
        cmd = build_command(prompt, model, **options)
        output, status = execute_with_retry(cmd, prompt, options)

        handle_errors(status, output)
        output
      end

      protected

      def execute_with_retry(cmd, prompt, options)
        output, status = run_with_timeout(cmd, prompt)
        return [output, status] unless should_retry?(status, output)

        run_with_timeout(build_retry_command(cmd, prompt, **options), prompt)
      end

      def run_with_timeout(cmd, prompt)
        Timeout.timeout(timeout_seconds) { run_command(cmd, prompt) }
      rescue Timeout::Error => e
        raise "#{adapter_name} timed out after #{timeout_seconds}s: #{e.message}"
      end

      def run_command(cmd, prompt)
        return Open3.capture2e(*cmd, stdin_data: prompt) if pipes_prompt_to_stdin?

        Open3.capture2e(*cmd)
      end

      def handle_errors(status, output)
        raise "#{adapter_name} command failed: #{output}" unless status.success?
      end

      def build_command(prompt, model, **options)
        raise NotImplementedError, "#{self.class} must implement #build_command"
      end

      def pipes_prompt_to_stdin?
        true
      end

      def should_retry?(_status, _output)
        false
      end

      def build_retry_command(cmd, _prompt, **_options)
        cmd
      end

      def timeout_seconds
        DEFAULT_TIMEOUT
      end

      def adapter_name
        self.class.name.split('::').last.sub('Adapter', '')
      end
    end
  end
end
