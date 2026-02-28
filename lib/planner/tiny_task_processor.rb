require 'ollama_client'

class TinyTaskProcessor
  def initialize
    # Assumes Ollama is running and qwen3:latest is available
    @client = Ollama::Client.new
  end

  def summarize_test_output(output)
    schema = {
      'type' => 'object',
      'required' => %w[failed_tests error_summary],
      'additionalProperties' => false,
      'properties' => {
        'failed_tests' => {
          'type' => 'array',
          'items' => { 'type' => 'string' }
        },
        'error_summary' => { 'type' => 'string' }
      }
    }

    @client.generate(
      prompt: <<~PROMPT,
        Extract failing tests and summarize errors from the following terminal output:

        #{output}
      PROMPT
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
