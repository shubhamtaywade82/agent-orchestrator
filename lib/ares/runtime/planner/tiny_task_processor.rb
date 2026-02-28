# frozen_string_literal: true

require 'ollama_client'

class TinyTaskProcessor
  def initialize
    # Assumes Ollama is running and qwen3:latest is available
    @client = Ollama::Client.new
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

    prompt = case type
             when :lint
               "Extract failing RuboCop offenses, summarize the style violations, and identify specific file paths and line numbers from the following output:\n\n#{output}"
             when :syntax
               "Extract Ruby syntax errors or compilation failures, summarize the root cause, and identify specific file paths and line numbers from the following output:\n\n#{output}"
             else
               "Extract failing tests, summarize errors, and identify specific file paths and line numbers where failures occurred from the following terminal output:\n\n#{output}"
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
