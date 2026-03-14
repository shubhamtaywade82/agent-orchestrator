# frozen_string_literal: true

module Ares
  module Orchestrator
    class Executor
      def execute(task)
        case task.type
        when :scan_repo
          files = Context::RepoScanner.new.scan(task.payload)
          puts "Found #{files.size} ruby files"
          files.each { |f| puts "  #{f}" }
          files

        when :build_context
          files = Context::ContextBuilder.new.build(task.payload)
          puts "Built context for #{files.size} files"
          files.each { |f| puts "  #{f}" }

        when :compress_context
          result = ContextEngine::Pipeline.build(task.payload)
          puts result[:compressed]
          result

        else
          puts "Unknown task #{task.type}"
        end
      end
    end
  end
end
