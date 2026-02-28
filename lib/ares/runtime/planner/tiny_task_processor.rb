# frozen_string_literal: true

require 'ollama_client'
require_relative '../config_manager'

module Ares
  module Runtime
    class TinyTaskProcessor
      MAX_SUMMARY_INPUT = 5_000

      def initialize
        config_data = ConfigManager.load_ollama
        config = Ollama::Config.new
        config.base_url = config_data[:base_url]
        config.timeout = config_data[:timeout] || 10 # 10s default for diagnostics
        config.num_ctx = config_data[:num_ctx]
        config.retries = config_data[:retries]

        @client = Ollama::Client.new(config: config)
      end

      def summarize_output(output, type: :test)
        schema = {
          'type' => 'object',
          'required' => %w[failed_items error_summary files],
          'additionalProperties' => false,
          'properties' => {
            'failed_items' => {
              'type' => 'array',
              'items' => { 'type' => 'string' }
            },
            'error_summary' => { 'type' => 'string' },
            'files' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => %w[path line],
                'properties' => {
                  'path' => { 'type' => 'string' },
                  'line' => { 'type' => 'integer' }
                }
              }
            }
          }
        }

        filtered = filter_output(output, type)
        truncated = if filtered.length > MAX_SUMMARY_INPUT
                      "#{filtered[0, MAX_SUMMARY_INPUT]}\n\n[... output truncated ...]"
                    else
                      filtered
                    end

        prompt = case type
                 when :lint
                   "Summarize RuboCop offenses. Extract file paths and line numbers from this filtered output:\n\n#{truncated}"
                 when :syntax
                   "Summarize Ruby syntax errors. Extract file paths and line numbers:\n\n#{truncated}"
                 else
                   "Summarize RSpec failures. Extract file paths and line numbers:\n\n#{truncated}"
                 end

        @client.generate(
          prompt: prompt,
          schema: schema
        )
      rescue StandardError => e
        # Safe Mode Fallback: Return a minimal summary to prevent blocking the diagnostic loop
        {
          'failed_items' => [],
          'error_summary' => "Safe Mode: Failed to summarize with Ollama (#{e.message.split("\n").first}).",
          'files' => []
        }
      end

      private

      def filter_output(output, type)
        lines = output.split("\n")
        case type
        when :lint
          # RuboCop: keep only lines containing offenses (C: or W:)
          lines.grep(/:\d+:\d+: [CW]: /).first(20).join("\n")
        when :test
          # RSpec: keep failing test titles, failure messages, and locations
          lines.select do |l|
            l.match?(/\d+\)\s/) || # "1) Router#run..."
              l.match?(%r{\s+Failure/Error:}) || # "Failure/Error: ..."
              l.match?(/\s+expected:/) ||
              l.match?(/\s+got:/) ||
              l.match?(/\.rb:\d+/) # Locations
          end.first(50).join("\n")
        else
          lines.first(100).join("\n")
        end
      end

      def summarize_diff(diff)
        schema = {
          'type' => 'object',
          'required' => %w[modified_files change_summary risk_level],
          'additionalProperties' => false,
          'properties' => {
            'modified_files' => {
              'type' => 'array',
              'items' => { 'type' => 'string' }
            },
            'change_summary' => { 'type' => 'string' },
            'risk_level' => {
              'type' => 'string',
              'enum' => %w[low medium high]
            }
          }
        }

        @client.generate(
          prompt: <<~PROMPT,
            Summarize the following git diff. Identify modified files, describe the core changes, and assess the risk level.

            #{diff}
          PROMPT
          schema: schema
        )
      end
    end
  end
end
