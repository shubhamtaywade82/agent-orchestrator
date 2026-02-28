# frozen_string_literal: true

require_relative '../planner/ollama_planner'
require_relative '../planner/tiny_task_processor'
require_relative 'context_loader'
require_relative 'model_selector'
require_relative 'task_logger'
require_relative 'quota_manager'
require_relative 'git_manager'
require_relative 'terminal_runner'
require_relative 'config_manager'
require_relative '../adapters/claude_adapter'
require_relative '../adapters/codex_adapter'
require_relative '../adapters/cursor_adapter'
require_relative '../adapters/ollama_adapter'
require 'tty-spinner'
require 'tty-table'
require 'tty-prompt'

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
    @tiny_processor = TinyTaskProcessor.new
    @spinner = TTY::Spinner.new('[:spinner] :title', format: :dots)

    # Special handling for diagnostic tasks (tests, fixes, diagnostics)
    return run_test_diagnostic(options) if /(run )?(test|rspec|fix|diagnostic)/i.match?(task)

    return run_syntax_check(options) if /syntax|compile/i.match?(task)

    return run_lint(options) if /lint|format|style/i.match?(task)

    plan = nil
    @spinner.update(title: 'Planning task with Ollama...')
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
    @spinner.update(title: "#{title} failed. Summarizing with local Ollama...")
    summary = nil
    @spinner.run { summary = @tiny_processor.summarize_output(result[:output], type: type) }

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
    escalate_to_executor(summary, options.merge(verify_command: command))
  end

  def escalate_to_executor(summary, options)
    type = options[:type] || :test
    verify_command = options[:verify_command] || 'bundle exec rspec'

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

    schema = {
      'type' => 'object',
      'required' => %w[explanation patches],
      'properties' => {
        'explanation' => { 'type' => 'string' },
        'patches' => {
          'type' => 'array',
          'items' => {
            'type' => 'object',
            'required' => %w[file content],
            'properties' => {
              'file' => { 'type' => 'string' },
              'content' => { 'type' => 'string' }
            }
          }
        }
      }
    }

    adapter = build_adapter(selection[:engine])

    @spinner.update(title: "Applying fix via #{selection[:engine]}...")
    result = nil
    @spinner.run do
      adapter = build_adapter(selection[:engine])
      if selection[:engine] == :ollama
        result = adapter.call(fix_prompt, selection[:model], schema: schema)
      else
        raw = adapter.call(fix_prompt, selection[:model])
        result = begin
          JSON.parse(raw)
        rescue StandardError
          { 'explanation' => raw, 'patches' => [] }
        end
      end
    rescue StandardError => e
      puts "\n⚠️ Fix failed via #{selection[:engine]}: #{e.message}. Retrying with local Ollama..."
      fallback_adapter = OllamaAdapter.new
      result = fallback_adapter.call(fix_prompt, schema: schema)
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
