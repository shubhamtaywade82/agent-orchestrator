# frozen_string_literal: true

require 'English'
require 'shellwords'

# Adapter for Claude CLI. Passes prompts via stdin to avoid ARG_MAX limits.
class ClaudeAdapter
  INSTRUCTION = 'Complete the task described above. Provide your response in the requested format.'

  def call(prompt, model)
    model ||= 'sonnet'
    cmd = "claude --model #{Shellwords.escape(model)} -p #{Shellwords.escape(INSTRUCTION)}"
    output = IO.popen(cmd, 'r+') do |io|
      io.write(prompt)
      io.close_write
      io.read
    end
    raise "Claude command failed: #{output}" unless $CHILD_STATUS.success?

    output
  end
end
