require_relative "../planner/ollama_planner"
require_relative "../planner/tiny_task_processor"
require_relative "context_loader"
require_relative "model_selector"
require_relative "task_logger"
require_relative "quota_manager"
require_relative "git_manager"
require_relative "terminal_runner"
require_relative "../adapters/claude_adapter"
require_relative "../adapters/codex_adapter"
require_relative "../adapters/cursor_adapter"
require_relative "quota_manager"
require_relative "git_manager"

class Router
  def initialize
    @planner = OllamaPlanner.new
    @logger = TaskLogger.new
  end

  def run(task, options = {})
    puts "Task ID: #{@logger.task_id}"

    if QuotaManager.quota_exceeded?
      puts "❌ Quota exceeded for Claude. Please try again later or use a different engine."
      exit 1
    end

    # Initialize tiny task processor for diagnostics
    @tiny_processor = TinyTaskProcessor.new

    # Special handling for diagnostic tasks
    if task =~ /run tests/i
      return run_test_diagnostic(options)
    end

    plan = @planner.plan(task)
    selection = ModelSelector.select(plan)

    puts "Plan: #{plan['task_type']} (Risk: #{plan['risk_level']}, Confidence: #{plan['confidence']})"
    if plan['slices']&.any?
      puts "Slices:"
      plan['slices'].each { |s| puts " - #{s}" }
    end
    puts "Selection: #{selection}"

    if options[:dry_run]
      puts "--- DRY RUN MODE ---"
      @logger.log_task(task, plan, selection)
      return
    end

    @logger.log_task(task, plan, selection)

    context = ContextLoader.load
    final_prompt = "#{context}\n\nTASK:\n#{task}"

    adapter = build_adapter(selection[:engine])

    if options[:git]
      puts "🌿 Creating git branch for task..."
      GitManager.create_branch(@logger.task_id)
    end

    QuotaManager.increment_usage(selection[:engine])
    result = adapter.call(final_prompt, selection[:model])

    @logger.log_result(result)

    if options[:git]
      puts "💾 Committing changes to git..."
      GitManager.commit_changes(@logger.task_id, task)
    end

    puts result
  end

  private

  def run_test_diagnostic(options)
    puts "Running tests..."
    result = TerminalRunner.run("bundle exec rspec")

    if result[:exit_status] == 0
      puts "All tests passed! ✅"
      return
    end

    puts "Tests failed. Summarizing with Ollama (qwen3:latest)..."
    summary = @tiny_processor.summarize_test_output(result[:output])

    puts "\n--- Diagnostic Summary ---"
    puts "Failed Tests: #{summary['failed_tests'].join(', ')}"
    puts "Error: #{summary['error_summary']}"

    if options[:dry_run]
      puts "Dry run: skipping escalation."
      return
    end

    # Escalate to executor for fix
    escalate_to_executor(summary, options)
  end

  def escalate_to_executor(summary, options)
    # Decompose the summary into a plan for the ModelSelector
    fix_plan = {
      "task_type" => "refactor",
      "risk_level" => "medium",
      "confidence" => 0.6 # Low confidence because it's a fix
    }

    selection = ModelSelector.select(fix_plan)
    puts "Selected Engine for fix: #{selection[:engine]} (#{selection[:model] || 'default'})"

    context = ContextLoader.load
    fix_prompt = <<~PROMPT
      #{context}

      DIAGNOSTIC SUMMARY:
      Failed Tests: #{summary['failed_tests'].join(', ')}
      Error: #{summary['error_summary']}

      TASK:
      Please fix the failing tests identified above. Apply the minimal necessary change to satisfy the test requirements.
    PROMPT

    adapter = build_adapter(selection[:engine])
    puts "Applying fix..."
    result = adapter.call(fix_prompt, selection[:model])
    puts result

    puts "\nVerifying fix..."
    verify_result = TerminalRunner.run("bundle exec rspec")
    if verify_result[:exit_status] == 0
      puts "Fix successful! All tests passed. ✅"
    else
      puts "Fix failed. Tests are still failing. ❌"
    end
  end

  def build_adapter(engine)
    case engine
    when :claude then ClaudeAdapter.new
    when :codex then CodexAdapter.new
    when :cursor then CursorAdapter.new
    else raise "Unknown engine"
    end
  end
end
