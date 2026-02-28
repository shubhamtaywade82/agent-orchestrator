require 'ollama_client'

class OllamaAdapter
  def initialize
    @client = Ollama::Client.new
  end

  def call(prompt, model = nil)
    model ||= best_available_model

    # Using the standard non-schema generation for general tasks
    @client.generate(prompt: prompt, model: model)
  end

  private

  def best_available_model
    available = @client.list_model_names
    return 'qwen3:latest' if available.include?('qwen3:latest')
    return 'qwen3:8b' if available.include?('qwen3:8b')

    available.first || 'qwen3:8b' # Fallback
  end
end
