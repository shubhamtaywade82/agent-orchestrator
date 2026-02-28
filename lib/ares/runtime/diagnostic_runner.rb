# frozen_string_literal: true

require_relative 'fix_applicator'

module Ares
  module Runtime
    # Runs diagnostic commands (tests, syntax, lint) and escalates failures to AI fix.
    class DiagnosticRunner
      def initialize(core:, spinner:)
        @core = core
        @spinner = spinner
      end

      def run_tests(options = {})
        run_loop('bundle exec rspec', options.merge(type: :test, title: 'Running tests'))
      end

      def run_syntax_check(options = {})
        cmd = "ruby -e 'Dir.glob(\"{lib,bin,exe,spec}/**/*.rb\").each { |f| (puts \"Checking \#{f}\"; system(\"ruby -c \#{f}\")) or exit(1) }'"
        run_loop(cmd, options.merge(type: :syntax, title: 'Checking syntax'))
      end

      def run_lint(options = {})
        run_loop('bundle exec rubocop -A', options.merge(type: :lint, title: 'Running RuboCop'))
      end

      def run_loop(command, options)
        title = options[:title] || 'Running verification'
        result = run_with_spinner(command, title)

        return report_success(title) if result[:exit_status].zero?

        summary = parse_summary(result[:output], title, options[:type] || :test)
        print_summary(summary, options[:type] || :test, title: title)

        return skip_escalation if options[:dry_run]

        applicator = FixApplicator.new(core: @core, spinner: @spinner, diagnostic_runner: self)
        result = applicator.escalate(
          type: options[:type] || :test,
          summary: summary,
          verify_command: command,
          fix_first_only: !!options[:fix_first_only]
        )

        return result if options[:fail_fast]
      end

      def print_summary(summary, type, title: nil)
        header = title || "Diagnostic Summary (#{type.to_s.upcase})"
        table = TTY::Table.new(header: %w[Attribute Value])
        table << ['Failed Items', Array(summary['failed_items'] || summary['failed_tests']).join("\n")]
        table << ['Error Summary', summary['error_summary']]
        puts "\n--- #{header} ---"
        puts table.render(:unicode, multiline: true)
      end

      private

      def run_with_spinner(command, title)
        @spinner.update(title: "#{title}...")
        result = nil
        @spinner.run { result = TerminalRunner.run(command) }
        result
      end

      def parse_summary(output, title, type)
        @spinner.update(title: "#{title} failed. Summarizing diagnostic output...")
        summary = nil
        @spinner.run do
          parsed = DiagnosticParser.parse(output, type: type)
          if parsed['files'].empty? && parsed['failed_items'].empty?
            @spinner.update(title: "#{title} failed. LLM Fallback (Slow)...")
            summary = @core.tiny_processor.summarize_output(output, type: type)
          else
            summary = parsed
          end
        end
        summary
      rescue StandardError => e
        @spinner.update(title: "#{title} failed. Error in fast-path: #{e.message}. LLM Fallback...")
        @spinner.run { @core.tiny_processor.summarize_output(output, type: type) }
      end

      def report_success(title)
        puts "#{title} passed! ✅"
        true
      end

      def skip_escalation
        puts 'Dry run: skipping escalation.'
        false
      end
    end
  end
end
