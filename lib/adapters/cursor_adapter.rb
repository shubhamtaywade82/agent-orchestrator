class CursorAdapter
  def call(prompt, _model=nil)
    `cursor agent "#{escape(prompt)}"`
  end

  private

  def escape(text)
    text.gsub('"', '\"')
  end
end
