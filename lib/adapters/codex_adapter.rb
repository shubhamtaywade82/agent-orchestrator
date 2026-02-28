class CodexAdapter
  def call(prompt, _model = nil)
    `codex exec "#{escape(prompt)}"`
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
