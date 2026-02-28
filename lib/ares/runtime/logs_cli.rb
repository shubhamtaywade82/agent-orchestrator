# frozen_string_literal: true

module Ares
  module Runtime
    class LogsCLI
      LOG_DIR = File.expand_path('~/.ares/logs')

      def self.run
        unless Dir.exist?(LOG_DIR)
          puts 'No logs found.'
          return
        end

        logs = Dir.glob("#{LOG_DIR}/*.log").sort.last(10).reverse

        logs.each do |file|
          puts "\n--- #{File.basename(file)} ---"
          puts File.read(file)
        end
      end
    end
  end
end
