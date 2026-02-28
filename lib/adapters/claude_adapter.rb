class ClaudeAdapter
  def call(prompt, model)
    model ||= 'sonnet'
    output = `claude --model #{model} "#{escape(prompt)}"`
    raise "Claude command failed: #{output}" unless $?.success?

    output
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
