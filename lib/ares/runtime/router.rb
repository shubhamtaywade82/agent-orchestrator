# frozen_string_literal: true

module Ares
  module Runtime
    class Router
      def initialize
        @planner = OllamaPlanner.new
        @logger = TaskLogger.new
      end

      def run(task, options = {})
        puts "Task ID: #{@logger.task_id}"

        if QuotaManager.quota_exceeded?
          puts '❌ Quota exceeded for Claude. Please try again later or use a different engine.'
          exit 1
        end

        # Initialize tiny task processor and spinner
        @tiny_processor = Ares::Runtime::TinyTaskProcessor.new
        @spinner = TTY::Spinner.new('[:spinner] :title', format: :dots)

        # Only match short command-like phrases; avoid hijacking descriptive tasks
        # e.g. "run linting" ✓ but "add linting to CI" ✗
        return run_test_diagnostic(options) if task.match?(/\A(run\s+)?(test|rspec|fix|diagnostic)(s|ing)?\s*\z/i)
        return run_syntax_check(options) if task.match?(/\A(run\s+)?(syntax|compile)(\s+check)?\s*\z/i)
        return run_lint(options) if task.match?(/\A(run\s+)?(lint|format|style)(ting|ing|s)?\s*\z/i)

        plan = nil
        @spinner.update(title: 'Planning task...')
        @spinner.run do
          plan = @planner.plan(task)
        end

        selection = nil
        @spinner.update(title: 'Selecting optimal model...')
        @spinner.run do
          selection = ModelSelector.select(plan)
        end

        puts "Task Type: #{plan['task_type']} | Risk: #{plan['risk_level']} | Confidence: #{plan['confidence']}"

        if plan['confidence'].to_f < 0.7
          prompt = TTY::Prompt.new
          choice = prompt.select('Low confidence detected. How should we proceed?',
                                 "Execute with suggested #{selection[:engine]} (#{selection[:model] || 'default'})",
                                 'Override and use Claude Opus',
                                 'Abort task')

          case choice
          when /Override/
            selection = { engine: :claude, model: 'opus' }
            puts 'Overridden: Using Claude Opus.'
          when /Abort/
            puts 'Task aborted by user.'
            return
          end
        end

        puts "Engine Selected: #{selection[:engine]} (#{selection[:model] || 'default'})"

        if plan['slices']&.any?
          puts 'Slices:'
          plan['slices'].each { |s| puts " - #{s}" }
        end

        if options[:dry_run]
          puts '--- DRY RUN MODE ---'
          @logger.log_task(task, plan, selection)
          return
        end

        @logger.log_task(task, plan, selection)

        context = ContextLoader.load
        final_prompt = "#{context}\n\nTASK:\n#{task}"

        adapter = build_adapter(selection[:engine])

        if options[:git]
          puts '🌿 Creating git branch for task...'
          GitManager.create_branch(@logger.task_id, task)
        end

        QuotaManager.increment_usage(selection[:engine])
        result = adapter.call(final_prompt, selection[:model])

        @logger.log_result(result)

        if options[:git]
          puts '💾 Committing changes to git...'
          GitManager.commit_changes(@logger.task_id, task)
        end

        puts result
      end

      private

      def run_test_diagnostic(options)
        run_diagnostic_loop('bundle exec rspec', options.merge(type: :test, title: 'Running tests'))
      end

      def run_syntax_check(options)
        # Check syntax for all ruby files in lib, bin, spec individually to catch all errors
        cmd = "ruby -e 'Dir.glob(\"{lib,bin,exe,spec}/**/*.rb\").each { |f| (puts \"Checking \#{f}\"; system(\"ruby -c \#{f}\")) or exit(1) }'"
        run_diagnostic_loop(cmd, options.merge(type: :syntax, title: 'Checking syntax'))
      end

      def run_diagnostic_loop(command, options)
        title = options[:title] || 'Running verification'
        @spinner.update(title: "#{title}...")
        result = nil
        @spinner.run { result = TerminalRunner.run(command) }

        if result[:exit_status].zero?
          puts "#{title} passed! ✅"
          return true
        end

        type = options[:type] || :test
        @spinner.update(title: "#{title} failed. Summarizing diagnostic output...")
        summary = nil

        @spinner.run do
          # Try fast-path regex/JSON parsing first
          summary = DiagnosticParser.parse(result[:output], type: type)

          # Fallback to LLM only if fast-path failed to identify files
          if summary['files'].empty? || summary['failed_items'].empty?
            @spinner.update(title: "#{title} failed. LLM Fallback (Slow)...")
            summary = @tiny_processor.summarize_output(result[:output], type: type)
          end
        rescue StandardError => e
          @spinner.update(title: "#{title} failed. Error in fast-path: #{e.message}. LLM Fallback...")
          summary = @tiny_processor.summarize_output(result[:output], type: type)
        end

        puts "\n--- Diagnostic Summary (#{type.to_s.upcase}) ---"
        table = TTY::Table.new(header: %w[Attribute Value])
        table << ['Failed Items', Array(summary['failed_items'] || summary['failed_tests']).join("\n")]
        table << ['Error Summary', summary['error_summary']]
        puts table.render(:unicode, multiline: true)

        if options[:dry_run]
          puts 'Dry run: skipping escalation.'
          return false
        end

        # Escalate to executor for fix
        if type == :lint
          escalate_lint_one_at_a_time(summary, options.merge(verify_command: command))
        else
          escalate_to_executor(summary, options.merge(verify_command: command))
        end
      end

      def escalate_lint_one_at_a_time(summary, options)
        max_iterations = 20
        current_summary = summary

        max_iterations.times do |iteration|
          puts "\n--- Fix iteration #{iteration + 1}/#{max_iterations} ---" if iteration.positive?

          success = escalate_to_executor(current_summary, options.merge(fix_first_only: true))
          return true if success

          @spinner.update(title: 'Re-running RuboCop...')
          verify_result = nil
          @spinner.run { verify_result = TerminalRunner.run(options[:verify_command]) }

          return false if verify_result[:exit_status].zero?

          @spinner.update(title: 'Summarizing remaining offenses...')
          current_summary = nil
          @spinner.run { current_summary = @tiny_processor.summarize_output(verify_result[:output], type: :lint) }

          puts "\n--- Remaining offenses ---"
          table = TTY::Table.new(header: %w[Attribute Value])
          table << ['Failed Items', Array(current_summary['failed_items']).join("\n")]
          table << ['Error Summary', current_summary['error_summary']]
          puts table.render(:unicode, multiline: true)
        end

        puts "\nReached max iterations (#{max_iterations}). Some offenses may remain."
        false
      end

      def escalate_to_executor(summary, options)
        type = options[:type] || :test
        verify_command = options[:verify_command] || 'bundle exec rspec'
        fix_first_only = options[:fix_first_only]

        fix_plan = {
          'task_type' => type == :test ? 'refactor' : 'architecture',
          'risk_level' => 'medium',
          'confidence' => 0.6
        }

        selection = ModelSelector.select(fix_plan)
        puts "Selected Engine for fix: #{selection[:engine]} (#{selection[:model] || 'default'})"

        context = ContextLoader.load
        fix_prompt = <<~PROMPT
          #{context}

          DIAGNOSTIC SUMMARY (#{type.to_s.upcase}):
          Failed Items: #{Array(summary['failed_items'] || summary['failed_tests']).join(', ')}
          Error: #{summary['error_summary']}

          TASK:
          Please fix the #{type} failures identified above. Apply the minimal necessary change.
          #{'Fix ONLY the first offense listed. Do not fix any others.' if fix_first_only}
          You MUST provide your response in JSON format matching the requested schema. Provide the FULL content of the file for the 'content' field.

          CRITICAL GUIDELINES:
          - Focus your fix ONLY on the files mentioned in the error summary.
          - DO NOT modify core system files in 'lib/core/' or 'lib/adapters/' or 'lib/planner/' unless they are the direct cause of the #{type} failure.
          - If you think the bug is in the engine, REFUSE to fix and instead explain why in the 'explanation' field.
          - Ensure your fix is minimal.

          FAILING FILE CONTENTS:
          #{Array(summary['files']).filter_map do |f|
            path = File.expand_path(f['path'], Dir.pwd)
            next unless File.exist?(path)

            "--- FILE: #{f['path']} ---\n#{File.read(path)}\n"
          end.join("\n")}

          PERTINENT PROJECT FILES (for reference):
          #{Dir.glob('{spec,lib}/**/*').reject { |f| File.directory?(f) }.join("\n")}
          #{Array(summary['files']).filter_map { |f| f['path'] }.uniq.join("\n")}
        PROMPT

        capable_engines = %i[claude codex cursor]
        initial_engine = selection[:engine]&.to_sym || :claude
        # Create chain: initial engine first, then others in preferred sequence
        fallback_chain = ([initial_engine] + (capable_engines - [initial_engine])).uniq

        result = nil
        attempts = 0
        max_attempts = fallback_chain.size

        @spinner.run do
          current_engine = fallback_chain[attempts]
          @spinner.update(title: "Applying fix via #{current_engine} (attempt #{attempts + 1}/#{max_attempts})...")

          adapter = build_adapter(current_engine)
          # Use custom model only for the first engine in the chain if it was explicitly selected
          current_model = (attempts.zero? && current_engine == initial_engine) ? selection[:model] : nil

          raw = adapter.call(fix_prompt, current_model)
          attempts += 1

          result = begin
            JSON.parse(raw)
          rescue StandardError
            { 'explanation' => raw, 'patches' => [] }
          end
        rescue StandardError => e
          attempts += 1
          if attempts < max_attempts
            next_engine = fallback_chain[attempts]
            puts "\n⚠️ #{fallback_chain[attempts - 1]} failed: #{e.message.split("\n").first.strip}. Retrying with #{next_engine}..."
            retry
          else
            raise "Escalation failed after #{attempts} attempts. Last error: #{e.message}"
          end
        end

        if result['patches']&.any?
          result['patches'].each do |patch|
            path = File.expand_path(patch['file'], Dir.pwd)
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, patch['content'])
            puts "Applied fix to #{patch['file']} ✅"
          end
        else
          puts "\nNo automated patches generated. Suggestion:"
          puts result['explanation']
        end

        @spinner.update(title: 'Verifying fix...')
        verify_result = nil
        @spinner.run { verify_result = TerminalRunner.run(verify_command) }

        if verify_result[:exit_status].zero?
          puts "Fix successful! #{type.to_s.capitalize} issues resolved. ✅"
          true
        else
          puts "Fix failed. #{type.to_s.capitalize} issues still persist. ❌"
          false
        end
      end

      def run_lint(options)
        run_diagnostic_loop('bundle exec rubocop -A', options.merge(type: :lint, title: 'Running RuboCop'))
      end

      def build_adapter(engine)
        case engine
        when :claude then ClaudeAdapter.new
        when :codex then CodexAdapter.new
        when :cursor then CursorAdapter.new
        when :ollama then OllamaAdapter.new
        else
          raise "Unsupported engine: #{engine}. Check your config/ares/models.yml"
        end
      end
    end
  end
end
