# frozen_string_literal: true
require_relative 'lib/ares/runtime/ollama_client_factory'
require_relative 'lib/ares/runtime/config_manager'
require 'ollama_client'

config_data = Ares::Runtime::ConfigManager.load_ollama
config = Ollama::Config.new
config.base_url = config_data[:base_url]
client = Ollama::Client.new(config: config)

available = client.list_model_names
puts "Available models: #{available.inspect}"
model = "sonnet"
puts "Does available include 'sonnet'? #{available.include?(model)}"
puts "Does available include :sonnet? #{available.include?(:sonnet)}"

def best_available_model(available)
  return 'qwen3:latest' if available.include?('qwen3:latest')
  return 'qwen3:8b' if available.include?('qwen3:8b')
  available.first || 'qwen3:8b'
end

selected_model = available.include?(model) ? model : best_available_model(available)
puts "Selected model for 'sonnet': #{selected_model}"
