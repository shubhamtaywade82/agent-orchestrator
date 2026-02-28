# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Ares
  module Runtime
    class ConfigManager
      GLOBAL_DIR = File.expand_path('~/.ares')

      # Public API -----------------------------------------------------------
      def self.load_models
        load_merged('models.yml')
      end

      def self.load_ollama
        load_merged('ollama.yml')
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

      # -------------------------------------------------------------------
      # Internal helpers
      def self.load_merged(filename)
        merged = {}
        merged = deep_merge(merged, load_file(gem_default_path(filename)))
        merged = deep_merge(merged, load_file(global_path(filename)))
        deep_merge(merged, load_file(local_path(filename)))
      end

      def self.load_file(path)
        return {} unless File.exist?(path)

        data = YAML.load_file(path)
        return {} unless data.is_a?(Hash)

        symbolize_keys(data)
      rescue StandardError
        {}
      end

      def self.save_config(filename, config)
        target = File.exist?(local_path(filename)) ? local_path(filename) : global_path(filename)
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, stringify_keys(config || {}).to_yaml)
      end

      # Path helpers --------------------------------------------------------
      def self.project_root
        dir = Dir.pwd

        loop do
          # Look for the namespaced config directory
          return dir if File.exist?(File.join(dir, 'config', 'ares', 'models.yml'))

          parent = File.dirname(dir)
          break if parent == dir

          dir = parent
        end

        Dir.pwd
      end

      def self.local_path(filename)
        File.join(project_root, 'config', 'ares', filename)
      end

      def self.global_path(filename)
        File.join(GLOBAL_DIR, filename)
      end

      def self.gem_default_path(filename)
        spec = Gem.loaded_specs['ares-runtime'] || begin
          Gem::Specification.find_by_name('ares-runtime')
        rescue StandardError
          nil
        end
        if spec
          File.join(spec.gem_dir, 'config', filename)
        else
          File.expand_path("../../config/#{filename}", __dir__)
        end
      end

      # Utility methods ------------------------------------------------------
      def self.deep_merge(hash1, hash2)
        result = hash1.dup
        hash2.each do |key, value|
          result[key] = if result[key].is_a?(Hash) && value.is_a?(Hash)
                          deep_merge(result[key], value)
                        else
                          value
                        end
        end
        result
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
