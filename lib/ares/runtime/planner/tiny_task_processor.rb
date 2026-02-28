# frozen_string_literal: true

require 'ollama_client'
require_relative '../config_manager'

class TinyTaskProcessor
  MAX_SUMMARY_INPUT = 12_000

  def initialize
    config_data = Ares::Runtime::ConfigManager.load_ollama
    config = Ollama::Config.new
    config.base_url = config_data[:base_url]
    config.timeout = config_data[:timeout] || 300
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

    truncated = if output.length > MAX_SUMMARY_INPUT
                  "#{output[0,
                            MAX_SUMMARY_INPUT]}\n\n[... output truncated ...]"
                else
                  output
                end

    prompt = case type
             when :lint
               "Extract failing RuboCop offenses, summarize the style violations, and identify specific file paths and line numbers from the following output:\n\n#{truncated}"
             when :syntax
               "Extract Ruby syntax errors or compilation failures, summarize the root cause, and identify specific file paths and line numbers from the following output:\n\n#{truncated}"
             else
               "Extract failing tests, summarize errors, and identify specific file paths and line numbers where failures occurred from the following terminal output:\n\n#{truncated}"
             end

    @client.generate(
      prompt: prompt,
      schema: schema
    )
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
