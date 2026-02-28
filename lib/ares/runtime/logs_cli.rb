# frozen_string_literal: true

module Ares
  module Runtime
    class LogsCLI
      def self.run
        project_log_dir = File.join(ConfigManager.project_root, 'logs')
        global_log_dir = File.expand_path('~/.ares/logs')

        log_dir = Dir.exist?(project_log_dir) ? project_log_dir : global_log_dir

        unless Dir.exist?(log_dir)
          puts "No logs found in #{log_dir}."
          return
        end

        logs = Dir.glob("#{log_dir}/*.json").sort_by { |f| File.mtime(f) }.last(10).reverse

        if logs.empty?
          puts "No JSON logs found in #{log_dir}."
          return
        end

        logs.each do |file|
          puts "\n--- Task: #{File.basename(file, '.json')} ---"
          data = JSON.parse(File.read(file))
          puts "Timestamp: #{data['timestamp']}"
          puts "Task:      #{data['task']}"
          puts "Engine:    #{data.dig('selection', 'engine')}"
          puts "Result:    #{data['result']&.slice(0, 100)}..."
        end
      end
    end
  end
end
