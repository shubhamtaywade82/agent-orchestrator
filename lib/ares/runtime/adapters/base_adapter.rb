# frozen_string_literal: true

require 'open3'
require 'timeout'

module Ares
  module Runtime
    # Abstract base class implementing the Template Method pattern for CLI adapters.
    # Defines the skeleton for execution, timeouts, and retries.
    class BaseAdapter
      DEFAULT_TIMEOUT = 30

      # Template Method: The core algorithm skeleton
      def call(prompt, model = nil, **options)
        cmd = build_command(prompt, model, **options)

        output, status = execute_with_timeout(cmd, prompt, timeout_seconds)

        if should_retry?(status, output)
          cmd = build_retry_command(cmd, prompt, **options)
          output, status = execute_with_timeout(cmd, prompt, timeout_seconds)
        end

        handle_errors(status, output)

        output
      end

      protected

      def execute_with_timeout(cmd, prompt, timeout)
        Timeout.timeout(timeout) do
          Open3.capture2e(*cmd, stdin_data: prompt)
        end
      rescue Timeout::Error => e
        raise "#{adapter_name} timed out after #{timeout}s: #{e.message}"
      end

      def handle_errors(status, output)
        raise "#{adapter_name} command failed: #{output}" unless status.success?
      end

      # Subclasses MUST implement this
      def build_command(prompt, model, **options)
        raise NotImplementedError, "#{self.class} must implement #build_command"
      end

      # Hook: Override in subclasses for complex retry logic
      def should_retry?(_status, _output)
        false
      end

      # Hook: Customize the command for the retry attempt
      def build_retry_command(cmd, _prompt, **_options)
        cmd
      end

      # Hook: Override for specific adapter timeouts
      def timeout_seconds
        DEFAULT_TIMEOUT
      end

      def adapter_name
        self.class.name.split('::').last.sub('Adapter', '')
      end
    end
  end
end
