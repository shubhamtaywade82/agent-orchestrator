# frozen_string_literal: true

module Ares
  module Runtime
    class Router
      def initialize
        @core = CoreSubsystem.new
      end

      def run(task, options = {})
        puts "Task ID: #{@core.logger.task_id}"
        check_quota!

        @spinner = TTY::Spinner.new('[:spinner] :title', format: :dots)

        shortcut_result = match_shortcut_task(task, options)
        return shortcut_result if shortcut_result

        plan = plan_task(task)
        selection = select_model_for_plan(plan)
        selection = handle_low_confidence(selection, plan)

        return if selection.nil? # User aborted

        execute_engine_task(task, plan, selection, options)
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
            summary = @core.tiny_processor.summarize_output(result[:output], type: type)
          end
        rescue StandardError => e
          @spinner.update(title: "#{title} failed. Error in fast-path: #{e.message}. LLM Fallback...")
          summary = @core.tiny_processor.summarize_output(result[:output], type: type)
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
          @spinner.run { current_summary = @core.tiny_processor.summarize_output(verify_result[:output], type: :lint) }

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
        fix_prompt = generate_fix_prompt(summary, options)

        selection = ModelSelector.select({ 'task_type' => 'refactor', 'risk_level' => 'medium' })
        puts "Selected Engine for fix: #{selection[:engine]} (#{selection[:model] || 'default'})"

        result = apply_fix_with_fallbacks(fix_prompt, selection)
        return false unless result

        apply_patches(result) if result['patches']&.any?

        @spinner.update(title: 'Verifying fix...')
        verify_result = nil
        @spinner.run { verify_result = TerminalRunner.run(verify_command) }

        handle_verification_result(verify_result, type)
      end

      def check_quota!
        return unless QuotaManager.quota_exceeded?

        puts '❌ Quota exceeded for Claude. Please try again later or use a different engine.'
        exit 1
      end

      def match_shortcut_task(task, options)
        if task.match?(/\A(run\s+|check\s+)?(test|rspec|fix|diagnostic)(s|ing)?\s*\z/i)
          return run_test_diagnostic(options)
        end
        return run_syntax_check(options) if task.match?(/\A(run\s+|check\s+)?(syntax|compile)(\s+check)?\s*\z/i)
        return run_lint(options) if task.match?(/\A(run\s+|check\s+)?(lint|format|style)(ting|ing|s)?\s*\z/i)

        nil
      end

      def plan_task(task)
        plan = nil
        @spinner.update(title: 'Planning task...')
        @spinner.run { plan = @core.planner.plan(task) }
        plan
      end

      def select_model_for_plan(plan)
        selection = nil
        @spinner.update(title: 'Selecting optimal model...')
        @spinner.run { selection = ModelSelector.select(plan) }
        selection
      end

      def handle_low_confidence(selection, plan)
        return selection if plan['confidence'].to_f >= 0.7

        prompt = TTY::Prompt.new
        choice = prompt.select('Low confidence detected. How should we proceed?',
                               "Execute with suggested #{selection[:engine]} (#{selection[:model] || 'default'})",
                               'Override and use Claude Opus', 'Abort task')

        case choice
        when /Override/
          puts 'Overridden: Using Claude Opus.'
          { engine: :claude, model: 'opus' }
        when /Abort/
          puts 'Task aborted by user.'
          nil
        else selection
        end
      end

      def execute_engine_task(task, plan, selection, options)
        puts "Engine Selected: #{selection[:engine]} (#{selection[:model] || 'default'})"
        return if options[:dry_run] && puts('--- DRY RUN MODE ---')

        @core.logger.log_task(task, plan, selection)
        GitManager.create_branch(@core.logger.task_id, task) if options[:git]

        capable_engines = %w[claude codex cursor]
        initial_engine = selection[:engine]&.to_s || 'claude'
        fallback_chain = ([initial_engine] + (capable_engines - [initial_engine])).uniq

        chain = EngineChain.build(fallback_chain)
        prompt = PromptBuilder.new
                              .add_context(ContextLoader.load)
                              .add_task(task)
                              .build

        adapter_opts = { model: selection[:model], fork_session: true, resume: true, cloud: options[:cloud] }

        output = chain.call(prompt, adapter_opts, total: fallback_chain.size)
        @core.logger.log_result(output)

        GitManager.commit_changes(@core.logger.task_id, task) if options[:git]
        puts output
      end

      def generate_fix_prompt(summary, options)
        type = options[:type] || :test

        builder = PromptBuilder.new
                               .add_context(ContextLoader.load)
                               .add_diagnostic(type, summary['failed_items'] || summary['failed_tests'], summary['error_summary'])
                               .add_instruction("TASK: Fix the #{type} failures identifying above.")

        builder.add_instruction('Fix ONLY the first offense listed.') if options[:fix_first_only]

        builder.add_instruction("You MUST provide JSON with 'explanation' and 'patches' (with 'file' and 'content' fields).")
               .add_files(summary['files'])
               .build
      end

      def apply_fix_with_fallbacks(fix_prompt, selection)
        capable_engines = %w[claude codex cursor]
        initial_engine = selection[:engine]&.to_s || 'claude'
        fallback_chain = ([initial_engine] + (capable_engines - [initial_engine])).uniq

        chain = EngineChain.build(fallback_chain)
        adapter_opts = { model: selection[:model], fork_session: true, resume: true }

        raw = chain.call_fix(fix_prompt, adapter_opts, total: fallback_chain.size) do |current_engine|
          create_checkpoint(current_engine)
        end
        parse_robust_json(raw)
      end

      def parse_robust_json(raw)
        json_str = raw.match(/```(?:json)?\s*(.*?)\s*```/m)&.captures&.first || raw
        begin
          JSON.parse(json_str)
        rescue JSON::ParserError => e
          puts "\n⚠️ Failed to parse valid JSON from the AI engine's response."
          puts "--- Raw Output ---\n#{raw}\n----------------"
          raise e
        end
      end

      def apply_patches(result)
        result['patches'].each do |patch|
          path = File.expand_path(patch['file'], Dir.pwd)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, patch['content'])
          puts "Applied fix to #{patch['file']} ✅"
        end
      end

      def handle_verification_result(verify_result, type)
        if verify_result[:exit_status].zero?
          puts "Fix successful! #{type.to_s.capitalize} issues resolved. ✅"
          true
        else
          puts "Fix failed. #{type.to_s.capitalize} issues still persist. ❌"
          false
        end
      end

      def create_checkpoint(engine)
        # Checkpointing logic varies by engine.
        # For now, we ensure a git-based safety net if not in a git repo or if native fails.
        case engine
        when :claude
          # Claude Code does automatic checkpointing on every prompt.
          @spinner.update(title: 'Leveraging Claude auto-checkpoint...')
        when :codex
          # Codex sessions are automatically persisted.
          @spinner.update(title: 'Leveraging Codex session persistence...')
        else
          # Fallback to git stash or similar if we wanted a hard checkpoint,
          # but since we are often on a task branch, git is our checkpoint.
          @spinner.update(title: "Ensuring state persistence for #{engine}...")
        end
      end

      def run_lint(options)
        run_diagnostic_loop('bundle exec rubocop -A', options.merge(type: :lint, title: 'Running RuboCop'))
      end
    end
  end
end
