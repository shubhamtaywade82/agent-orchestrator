require 'English'
class CodexAdapter
<<<<<<< Updated upstream
  def call(prompt, _model=nil)
    `codex exec "#{escape(prompt)}"`
=======
  def call(prompt, _model = nil)
    output = `codex exec "#{escape(prompt)}"`
    raise "Codex command failed: #{output}" unless $CHILD_STATUS.success?

    output
>>>>>>> Stashed changes
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
