class CodexAdapter
  def call(prompt, _model = nil)
    output = `codex exec "#{escape(prompt)}"`
    raise "Codex command failed: #{output}" unless $?.success?

    output
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
