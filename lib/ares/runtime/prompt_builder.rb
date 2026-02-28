# frozen_string_literal: true

module Ares
  module Runtime
    # Implements the Builder Pattern for constructing complex LLM prompts
    class PromptBuilder
      def initialize
        @sections = []
      end

      def add_context(context)
        @sections << context unless context.to_s.strip.empty?
        self
      end

      def add_task(task_description)
        @sections << "TASK:\n#{task_description}"
        self
      end

      def add_diagnostic(type, failed_items, error_summary)
        @sections << <<~DIAG.strip
          DIAGNOSTIC SUMMARY (#{type.to_s.upcase}):
          Failed Items: #{Array(failed_items).join(', ')}
          Error: #{error_summary}
        DIAG
        self
      end

      def add_files(files)
        return self if files.nil? || files.empty?

        files_content = Array(files).filter_map do |f|
          path = File.expand_path(f['path'], Dir.pwd)
          "--- FILE: #{f['path']} ---\n#{File.read(path)}" if File.exist?(path)
        end.join("\n\n")

        @sections << "FAILING FILE CONTENTS:\n#{files_content}" unless files_content.empty?
        self
      end

      def add_instruction(instruction)
        @sections << instruction unless instruction.to_s.strip.empty?
        self
      end

      def build
        @sections.join("\n\n")
      end
    end
  end
end
