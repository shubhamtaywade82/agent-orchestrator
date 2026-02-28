# frozen_string_literal: true

require 'fileutils'

module Ares
  module Runtime
    class Initializer
      def self.run
        root = ConfigManager.project_root
        target = File.join(root, 'config', 'ares')

        if Dir.exist?(target)
          puts 'Ares already initialized.'
          return
        end

        FileUtils.mkdir_p(target)
        copy_default('models.yml', target)
        copy_default('ollama.yml', target)

        puts "Initialized Ares in #{target}"
      end

      def self.copy_default(file, target)
        source = ConfigManager.gem_default_path(file)
        FileUtils.cp(source, File.join(target, file)) if File.exist?(source)
      end
    end
  end
end
