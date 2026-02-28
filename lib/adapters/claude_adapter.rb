require 'English'
class ClaudeAdapter
  def call(prompt, model)
<<<<<<< Updated upstream
    model ||= "sonnet"
    `claude --model #{model} "#{escape(prompt)}"`
=======
    model ||= 'sonnet'
    output = `claude --model #{model} "#{escape(prompt)}"`
    raise "Claude command failed: #{output}" unless $CHILD_STATUS.success?

    output
>>>>>>> Stashed changes
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
