# frozen_string_literal: true

require 'English'
class CodexAdapter
  def call(prompt, _model = nil)
    output = `codex exec "#{escape(prompt)}"`
    raise "Codex command failed: #{output}" unless $CHILD_STATUS.success?

    output
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
