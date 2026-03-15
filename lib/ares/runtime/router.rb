# frozen_string_literal: true

require_relative 'diagnostic_runner'

module Ares
  module Runtime
    class Router
      SHORTCUT_PATTERNS = {
        /\A(run\s+|check\s+)?(test|rspec|fix|diagnostic)(s|ing)?\s*\z/i => :run_test_diagnostic,
        /\A(run\s+|check\s+)?(syntax|compile)(\s+check)?\s*\z/i => :run_syntax_check,
        /\A(run\s+|check\s+)?(lint|format|style)(ting|ing|s)?\s*\z/i => :run_lint
      }.freeze

      def initialize
        @core = CoreSubsystem.new
      end

      def run(task, options = {})
        puts "Task ID: #{@core.logger.task_id}"
        check_quota!

        @spinner = TTY::Spinner.new('[:spinner] :title', format: :dots)
        @diagnostic = DiagnosticRunner.new(core: @core, spinner: @spinner)

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
        @diagnostic.run_tests(options)
      end

      def run_syntax_check(options)
        @diagnostic.run_syntax_check(options)
      end

      def run_lint(options)
        @diagnostic.run_lint(options)
      end

      def check_quota!
        return unless QuotaManager.quota_exceeded?

        puts '❌ Quota exceeded for Claude. Please try again later or use a different engine.'
        exit 1
      end

      def match_shortcut_task(task, options)
        SHORTCUT_PATTERNS.each do |pattern, method|
          return send(method, options) if task.match?(pattern)
        end
        nil
      end

      def plan_task(task)
        @spinner.update(title: 'Planning task...')
        @spinner.run { @core.planner.plan(task) }
      end

      def select_model_for_plan(plan)
        @spinner.update(title: 'Selecting optimal model...')
        @spinner.run { ModelSelector.select(plan) }
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
        if options[:dry_run]
          puts '--- DRY RUN MODE ---'
          return
        end

        @core.logger.log_task(task, plan, selection)
        GitManager.create_branch(@core.logger.task_id, task) if options[:git]

        fallback = EngineChain.build_fallback(selection[:engine] || :claude)
        prompt_builder = PromptBuilder.new.add_context(ContextLoader.load).add_task(task)
        prompt_builder.add_instruction('Do not ask clarifying questions. If the task is ambiguous, assume the most common interpretation and proceed. Output only the requested deliverable.') unless options[:interactive]
        prompt = prompt_builder.build

        adapter_opts = { model: selection[:model], fork_session: true, resume: true, cloud: options[:cloud], interactive: options[:interactive] }

        if options[:interactive]
          run_interactive_loop(fallback, prompt, adapter_opts, options)
        else
          output = fallback[:chain].call(prompt, adapter_opts, total: fallback[:size])
          @core.logger.log_result(output)
          GitManager.commit_changes(@core.logger.task_id, task) if options[:git]
          puts output
        end
      end

      # Agent CLIs are typically one-shot (read prompt, print response, exit). So we run
      # the agent again for each user reply, passing conversation history in the prompt.
      def run_interactive_loop(fallback, initial_prompt, adapter_opts, options)
        conversation = []
        prompt = initial_prompt
        max_turns = 10

        max_turns.times do
          opts = adapter_opts.merge(interactive: false)
          opts[:timeout_seconds] = 120 if conversation.any?  # follow-up turns have large context
          output = fallback[:chain].call(prompt, opts, total: fallback[:size])
          @core.logger.log_result(output)
          puts output

          break unless asks_question?(output)

          reply = prompt_user_reply
          break if reply.nil? || reply.strip.empty? || reply.strip.match?(/\A(done|exit|quit|q)\z/i)

          conversation << "Agent: #{output}" << "User: #{reply}"
          prompt = "#{initial_prompt}\n\n--- Conversation so far ---\n#{conversation.join("\n\n")}\n\n--- Continue (respond to the user's last message) ---"
        end

        GitManager.commit_changes(@core.logger.task_id, ARGV.join(' ')) if options[:git]
      end

      def asks_question?(text)
        return false if text.nil? || text.empty?

        trimmed = text.strip
        last_line = trimmed.lines.map(&:strip).reject(&:empty?).last
        last_line&.end_with?('?') || trimmed.include?('(y/n)') || trimmed.include?('work for you')
      end

      def prompt_user_reply
        print "\nYou: "
        $stdout.flush
        $stdin.gets
      end

    end
  end
end
