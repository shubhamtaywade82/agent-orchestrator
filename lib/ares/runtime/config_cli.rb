# frozen_string_literal: true

module Ares
  module Runtime
    class ConfigCLI
      def self.run
        models = ConfigManager.load_models
        ollama = ConfigManager.load_ollama

        puts "\nModels Configuration:"
        puts models.to_yaml

        puts "\nOllama Configuration:"
        puts ollama.to_yaml
      end
    end
  end
end
