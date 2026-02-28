# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Ares
  module Runtime
    class ConfigManager
      GLOBAL_DIR = File.expand_path('~/.ares')
      LOCAL_DIR = File.join(Dir.pwd, 'config')

      def self.load_models
        load_config('models.yml')
      end

      def self.load_ollama
        load_config('ollama.yml')
      end

      def self.save_models(config)
        save_config('models.yml', config)
      end

      def self.save_ollama(config)
        save_config('ollama.yml', config)
      end

      def self.task_types
        load_models.keys
      end

      def self.update_task_config(task_type, engine, model = nil)
        config = load_models
        config[task_type] = { engine: engine, model: model }
        save_models(config)
      end

      def self.project_root
        dir = Dir.pwd

        loop do
          return dir if File.exist?(File.join(dir, 'config', 'models.yml'))

          parent = File.dirname(dir)
          break if parent == dir

          dir = parent
        end

        Dir.pwd
      end

      def self.local_dir
        File.join(project_root, 'config')
      end

      def self.load_config(filename)
        # 1️⃣ Local project config
        local_path = File.join(local_dir, filename)
        if File.exist?(local_path)
          data = YAML.load_file(local_path)
          return symbolize_keys(data) if data.is_a?(Hash)
        end

        # 2️⃣ Global config
        global_path = File.join(GLOBAL_DIR, filename)
        if File.exist?(global_path)
          data = YAML.load_file(global_path)
          return symbolize_keys(data) if data.is_a?(Hash)
        end

        # 3️⃣ Gem defaults
        gem_default = gem_default_path(filename)
        if File.exist?(gem_default)
          data = YAML.load_file(gem_default)
          return symbolize_keys(data) if data.is_a?(Hash)
        end

        {}
      end

      def self.gem_default_path(filename)
        gem_root = Gem::Specification.find_by_name('agent-orchestrator').gem_dir
        File.join(gem_root, 'config', filename)
      end

      def self.save_config(filename, config)
        # If local config exists, update it. Otherwise, update global.
        local_path = File.join(local_dir, filename)
        target_path = File.exist?(local_path) ? local_path : File.join(GLOBAL_DIR, filename)

        FileUtils.mkdir_p(File.dirname(target_path))
        File.write(target_path, stringify_keys(config || {}).to_yaml)
      end

      def self.symbolize_keys(hash)
        return {} unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(k, v), h|
          key = begin
            k.to_sym
          rescue StandardError
            k
          end
          h[key] = v.is_a?(Hash) ? symbolize_keys(v) : v
        end
      end

      def self.stringify_keys(hash)
        return {} unless hash.is_a?(Hash)

        hash.transform_keys(&:to_s).each_with_object({}) do |(k, v), h|
          h[k] = v.is_a?(Hash) ? stringify_keys(v) : v
        end
      end
    end
  end
end
