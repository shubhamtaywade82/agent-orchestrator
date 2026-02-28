# frozen_string_literal: true

require 'json'

module Ares
  module Runtime
    # Parses RuboCop and RSpec JSON output into a unified diagnostic structure.
    # Avoids sending raw logs to LLMs for summarization.
    class DiagnosticParser
      def self.parse(output, type:)
        return fallback_parse(output, type) if output.nil? || output.strip.empty?

        clean_output = strip_ansi(output)
        case type
        when :lint then parse_rubocop(clean_output)
        when :syntax then parse_syntax(clean_output)
        else parse_rspec(clean_output)
        end
      end

      def self.strip_ansi(text)
        text.to_s.gsub(/\e\[([;\d]+)?m/, '')
      end

      def self.parse_rubocop(output)
        data = JSON.parse(output)
        failed_items = []
        files = []

        data['files']&.each do |file|
          path = file['path']
          file['offenses']&.each do |offense|
            line = offense.dig('location', 'line') || offense.dig('location', 'start_line')
            failed_items << "#{path}:#{line}: #{offense['message']}"
            files << { 'path' => path, 'line' => line.to_i }
          end
        end

        {
          'failed_items' => failed_items,
          'error_summary' => build_error_summary(failed_items, 'RuboCop'),
          'files' => remove_duplicates(files)
        }
      rescue JSON::ParserError
        parse_text_rubocop(output)
      end

      def self.parse_text_rubocop(output)
        failed_items = []
        files = []
        output.each_line do |line|
          # Match standard RuboCop line: path:line:col: C: Message
          # Using match instead of match? to capture data safely
          m = line.match(/([^:\s]+):(\d+):(\d+): ([A-Z]): (.+)/)
          next unless m

          path = m[1]&.strip
          line_num = m[2].to_i
          letter = m[4]
          msg = m[5]&.strip

          next unless path && msg

          # Only collect if it looks like a real RuboCop offense level
          if %w[C W E F].include?(letter)
            failed_items << "#{path}:#{line_num}: #{msg}"
            files << { 'path' => path, 'line' => line_num }
          end
        end

        {
          'failed_items' => failed_items,
          'error_summary' => build_error_summary(failed_items, 'RuboCop'),
          'files' => remove_duplicates(files)
        }
      end

      def self.parse_rspec(output)
        data = JSON.parse(output)
        failed_items = []
        files = []

        data['examples']&.each do |ex|
          next unless ex['status'] == 'failed'

          path = ex['file_path']&.delete_prefix('./')
          line = ex['line_number']
          msg = ex.dig('exception', 'message') || ex['full_description']
          failed_items << "#{path}:#{line}: #{msg}"
          files << { 'path' => path, 'line' => line.to_i }
        end

        {
          'failed_items' => failed_items,
          'error_summary' => build_error_summary(failed_items, 'RSpec'),
          'files' => remove_duplicates(files)
        }
      rescue JSON::ParserError
        parse_text_rspec(output)
      end

      def self.parse_text_rspec(output)
        failed_items = []
        files = []
        # Match typical RSpec failure location: # ./path/to/spec.rb:123:in `...'
        output.scan(%r{#\s+\./(.+?):(\d+):in}).each do |path, line|
          failed_items << "Failure at #{path}:#{line}"
          files << { 'path' => path, 'line' => line.to_i }
        end

        {
          'failed_items' => failed_items,
          'error_summary' => build_error_summary(failed_items, 'RSpec'),
          'files' => remove_duplicates(files)
        }
      end

      def self.parse_syntax(output)
        failed_items = []
        files = []
        output.each_line do |line|
          m = line.match(/\A(.+?):(\d+):\s*(.+)\z/)
          next unless m

          path = m[1].strip
          line_num = m[2].to_i
          msg = m[3].strip
          failed_items << "#{path}:#{line_num}: #{msg}"
          files << { 'path' => path, 'line' => line_num }
        end

        {
          'failed_items' => failed_items,
          'error_summary' => build_error_summary(failed_items, 'syntax'),
          'files' => remove_duplicates(files)
        }
      end

      def self.build_error_summary(failed_items, source)
        count = failed_items.size
        return "No #{source} issues found." if count.zero?

        "There are #{count} failed #{source.downcase} item(s)."
      end

      def self.remove_duplicates(files)
        files.uniq { |f| [f['path'], f['line']] }
      end

      def self.fallback_parse(output, type)
        {
          'failed_items' => [output.to_s.lines.first(50).join],
          'error_summary' => "Parsed #{type} output via fallback.",
          'files' => []
        }
      end
    end
  end
end
