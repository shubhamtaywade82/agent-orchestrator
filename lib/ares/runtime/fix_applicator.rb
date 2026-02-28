# frozen_string_literal: true

module Ares
  module Runtime
    # Escalates diagnostic failures to AI engines and applies patches.
    class FixApplicator
      MAX_LINT_ITERATIONS = 20

      def initialize(core:, spinner:, diagnostic_runner:)
        @core = core
        @spinner = spinner
        @diagnostic_runner = diagnostic_runner
      end

      def escalate(type:, summary:, verify_command:, fix_first_only: false)
        type == :lint ? escalate_lint_iteratively(summary, verify_command) : escalate_once(summary, type, verify_command)
      end

      private

      def escalate_lint_iteratively(summary, verify_command)
        current_summary = summary

        MAX_LINT_ITERATIONS.times do |iteration|
          puts "\n--- Fix iteration #{iteration + 1}/#{MAX_LINT_ITERATIONS} ---" if iteration.positive?

          success = escalate_once(current_summary, :lint, verify_command, fix_first_only: true)
          return true if success

          verify_result = rerun_and_summarize(verify_command)
          return false if verify_result[:exit_status].zero?

          current_summary = verify_result[:summary]
          @diagnostic_runner.print_summary(current_summary, :lint, title: 'Remaining offenses')
        end

        puts "\nReached max iterations (#{MAX_LINT_ITERATIONS}). Some offenses may remain."
        false
      end

      def escalate_once(summary, type, verify_command, fix_first_only: false)
        selection = ModelSelector.select({ 'task_type' => 'refactor', 'risk_level' => 'medium' })
        puts "Selected Engine for fix: #{selection[:engine]} (#{selection[:model] || 'default'})"

        result = apply_fix_with_fallbacks(build_fix_prompt(summary, type, fix_first_only), selection)
        return false unless result

        apply_patches(result) if result['patches']&.any?

        verify_result = run_verify(verify_command)
        handle_verification(verify_result, type)
      end

      def rerun_and_summarize(verify_command)
        @spinner.update(title: 'Re-running RuboCop...')
        verify_result = nil
        @spinner.run { verify_result = TerminalRunner.run(verify_command) }

        return { exit_status: verify_result[:exit_status], summary: nil } if verify_result[:exit_status].zero?

        @spinner.update(title: 'Summarizing remaining offenses...')
        summary = nil
        @spinner.run { summary = @core.tiny_processor.summarize_output(verify_result[:output], type: :lint) }
        { exit_status: verify_result[:exit_status], summary: summary }
      end

      def build_fix_prompt(summary, type, fix_first_only)
        builder = PromptBuilder.new
                               .add_context(ContextLoader.load)
                               .add_diagnostic(type, summary['failed_items'] || summary['failed_tests'], summary['error_summary'])
                               .add_instruction("TASK: Fix the #{type} failures identified above.")

        builder.add_instruction('Fix ONLY the first offense listed.') if fix_first_only

        builder.add_instruction("You MUST provide JSON with 'explanation' and 'patches' (with 'file' and 'content' fields).")
               .add_files(summary['files'])
               .build
      end

      def apply_fix_with_fallbacks(fix_prompt, selection)
        fallback = EngineChain.build_fallback(selection[:engine] || :claude)
        adapter_opts = { model: selection[:model], fork_session: true, resume: true }

        raw = fallback[:chain].call_fix(fix_prompt, adapter_opts, total: fallback[:size]) do |engine|
          @spinner.update(title: checkpoint_message(engine))
        end
        parse_json(raw)
      end

      def parse_json(raw)
        json_str = raw.match(/```(?:json)?\s*(.*?)\s*```/m)&.captures&.first || raw
        JSON.parse(json_str)
      rescue JSON::ParserError => e
        puts "\n⚠️ Failed to parse valid JSON from the AI engine's response."
        puts "--- Raw Output ---\n#{raw}\n----------------"
        raise e
      end

      def apply_patches(result)
        result['patches'].each do |patch|
          path = File.expand_path(patch['file'], Dir.pwd)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, patch['content'])
          puts "Applied fix to #{patch['file']} ✅"
        end
      end

      def run_verify(verify_command)
        @spinner.update(title: 'Verifying fix...')
        result = nil
        @spinner.run { result = TerminalRunner.run(verify_command) }
        result
      end

      def handle_verification(verify_result, type)
        if verify_result[:exit_status].zero?
          puts "Fix successful! #{type.to_s.capitalize} issues resolved. ✅"
          true
        else
          puts "Fix failed. #{type.to_s.capitalize} issues still persist. ❌"
          false
        end
      end

      def checkpoint_message(engine)
        case engine.to_s
        when 'claude' then 'Leveraging Claude auto-checkpoint...'
        when 'codex' then 'Leveraging Codex session persistence...'
        else "Ensuring state persistence for #{engine}..."
        end
      end
    end
  end
end
