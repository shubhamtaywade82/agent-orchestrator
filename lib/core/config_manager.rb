require 'yaml'

module Ares
  module Runtime
    class ConfigManager
      CONFIG_PATH = File.expand_path('../../config/models.yml', __dir__)

      def self.load
        YAML.safe_load(File.read(CONFIG_PATH), symbolize_names: true)
      rescue Errno::ENOENT
        {}
      end

      def self.save(config)
        # Convert symbolized keys back to strings for cleaner YAML if needed,
        # but Ruby's YAML.dump handles symbols fine as well.
        File.write(CONFIG_PATH, YAML.dump(config.transform_keys(&:to_s)))
      end

      def self.task_types
        load.keys
      end

      def self.update_task_config(task_type, engine, model)
        config = load
        config[task_type] ||= {}
        config[task_type][:engine] = engine
        config[task_type][:model] = model
        save(config)
      end
    end
  end
end
