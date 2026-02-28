# frozen_string_literal: true

require 'ollama_client'
require 'timeout'
require_relative '../config_manager'
require_relative '../ollama_client_factory'

module Ares
  module Runtime
    class TinyTaskProcessor
      MAX_SUMMARY_INPUT = 5_000
      DEFAULT_TIMEOUT = 30
      HARD_TIMEOUT = 35

      def initialize(healthy: true)
        @healthy = healthy
        @client = healthy ? OllamaClientFactory.build(timeout_seconds: DEFAULT_TIMEOUT) : nil
      end

      def summarize_output(output, type: :test)
        return safe_summary_fallback('Safe Mode: Ollama skipped') unless @healthy

        truncated = filter_and_truncate(output, type)
        prompt = build_summary_prompt(truncated, type)

        OllamaClientFactory.with_resilience(
          hard_timeout: HARD_TIMEOUT,
          fallback_value: safe_summary_fallback('Summary failed')
        ) do
          @client.generate(prompt: prompt, schema: summary_schema)
        end
      end

      def summarize_diff(diff)
        return safe_diff_fallback('Safe Mode: Ollama skipped') unless @healthy

        OllamaClientFactory.with_resilience(
          hard_timeout: HARD_TIMEOUT,
          fallback_value: safe_diff_fallback('Diff summary failed')
        ) do
          @client.generate(prompt: build_diff_prompt(diff), schema: diff_schema)
        end
      end

      private

      def filter_and_truncate(output, type)
        filtered = filter_output(output, type)
        return filtered if filtered.length <= MAX_SUMMARY_INPUT

        "#{filtered[0, MAX_SUMMARY_INPUT]}\n\n[... output truncated ...]"
      end

      def build_summary_prompt(truncated, type)
        instruction = case type
                      when :lint then 'Summarize RuboCop offenses. Extract file paths and line numbers:'
                      when :syntax then 'Summarize Ruby syntax errors. Extract file paths and line numbers:'
                      else 'Summarize RSpec failures. Extract file paths and line numbers:'
                      end

        PromptBuilder.new
                     .add_instruction(instruction)
                     .add_instruction(truncated)
                     .build
      end

      def build_diff_prompt(diff)
        PromptBuilder.new
                     .add_instruction('Summarize the following git diff. Identify modified files, describe the core changes, and assess the risk level.')
                     .add_instruction(diff)
                     .build
      end

      def summary_schema
        {
          'type' => 'object',
          'required' => %w[failed_items error_summary files],
          'properties' => {
            'failed_items' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
            'error_summary' => { 'type' => 'string' },
            'files' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => %w[path line],
                'properties' => { 'path' => { 'type' => 'string' }, 'line' => { 'type' => 'integer' } }
              }
            }
          }
        }
      end

      def diff_schema
        {
          'type' => 'object',
          'required' => %w[modified_files change_summary risk_level],
          'properties' => {
            'modified_files' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
            'change_summary' => { 'type' => 'string' },
            'risk_level' => { 'type' => 'string', 'enum' => %w[low medium high] }
          }
        }
      end

      def safe_summary_fallback(reason)
        { 'failed_items' => [], 'error_summary' => "Safe Mode: #{reason}", 'files' => [] }
      end

      def safe_diff_fallback(reason)
        { 'modified_files' => [], 'change_summary' => "Safe Mode: #{reason}", 'risk_level' => 'medium' }
      end

      def filter_output(output, type)
        lines = output.split("\n")
        case type
        when :lint
          lines.grep(/:\d+:\d+: [CW]: /).first(20).join("\n")
        when :test
          lines.select do |l|
            l.match?(/\d+\)\s/) || l.match?(%r{\s+Failure/Error:}) ||
              l.match?(/\s+expected:/) || l.match?(/\s+got:/) || l.match?(/\.rb:\d+/)
          end.first(50).join("\n")
        else
          lines.first(100).join("\n")
        end
      end
    end
  end
end
