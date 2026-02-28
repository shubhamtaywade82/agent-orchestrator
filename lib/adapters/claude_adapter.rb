class ClaudeAdapter
  def call(prompt, model)
    model ||= "sonnet"
    `claude --model #{model} "#{escape(prompt)}"`
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
