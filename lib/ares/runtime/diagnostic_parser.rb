# frozen_string_literal: true

require 'json'

module Ares
  module Runtime
    # Parses RuboCop and RSpec JSON output into a unified diagnostic structure.
    # Avoids sending raw logs to LLMs for summarization.
    class DiagnosticParser
      def self.parse(output, type:)
        case type
        when :lint then parse_rubocop(output)
        when :syntax then parse_syntax(output)
        else parse_rspec(output)
        end
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
            files << { 'path' => path, 'line' => line.to_i } unless files.any? do |f|
              f['path'] == path && f['line'] == line.to_i
            end
          end
        end

        {
          'failed_items' => failed_items,
          'error_summary' => build_error_summary(failed_items, 'RuboCop'),
          'files' => files.uniq { |f| [f['path'], f['line']] }
        }
      rescue JSON::ParserError
        fallback_parse(output, 'lint')
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
          'files' => files.uniq { |f| [f['path'], f['line']] }
        }
      rescue JSON::ParserError
        fallback_parse(output, 'test')
      end

      def self.parse_syntax(output)
        failed_items = []
        files = []
        output.each_line do |line|
          next unless line =~ /\A(.+?):(\d+):\s*(.+)\z/

          path = Regexp.last_match(1).strip
          line_num = Regexp.last_match(2).to_i
          msg = Regexp.last_match(3).strip
          failed_items << "#{path}:#{line_num}: #{msg}"
          files << { 'path' => path, 'line' => line_num }
        end

        {
          'failed_items' => failed_items,
          'error_summary' => build_error_summary(failed_items, 'syntax'),
          'files' => files.uniq { |f| [f['path'], f['line']] }
        }
      end

      def self.build_error_summary(failed_items, source)
        count = failed_items.size
        return "No #{source} issues found." if count.zero?

        "There are #{count} failed #{source.downcase} item(s)."
      end

      def self.fallback_parse(output, type)
        {
          'failed_items' => [output.lines.first(50).join],
          'error_summary' => "Could not parse #{type} output as JSON. Raw output provided.",
          'files' => []
        }
      end
    end
  end
end
