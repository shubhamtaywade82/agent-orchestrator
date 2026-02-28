# frozen_string_literal: true

require_relative 'runtime/config_manager'
require 'fileutils'

module Ares
  class CLI
    def self.init
      root = Ares::Runtime::ConfigManager.project_root
      target_dir = File.join(root, 'config', 'ares')

      if Dir.exist?(target_dir)
        puts "Ares config already exists at #{target_dir}"
        return
      end

      FileUtils.mkdir_p(target_dir)

      copy_default('models.yml', target_dir)
      copy_default('ollama.yml', target_dir)

      puts "Ares initialized at #{target_dir}"
    end

    def self.copy_default(filename, target_dir)
      gem_root = Gem::Specification.find_by_name('agent-orchestrator').gem_dir
      source = File.join(gem_root, 'config', filename)

      unless File.exist?(source)
        puts "Warning: default #{filename} not found in gem."
        return
      end

      FileUtils.cp(source, File.join(target_dir, filename))
    end
  end
end
