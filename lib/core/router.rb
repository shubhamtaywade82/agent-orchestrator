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
require "tty-spinner"
require "tty-table"
require "tty-prompt"

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

    # Initialize tiny task processor and spinner
    @tiny_processor = TinyTaskProcessor.new
    @spinner = TTY::Spinner.new("[:spinner] :title", format: :dots)

    # Special handling for diagnostic tasks
    if task =~ /run tests/i
      return run_test_diagnostic(options)
    end

    plan = nil
    @spinner.update(title: "Planning task with Ollama...")
    @spinner.run do
      plan = @planner.plan(task)
    end

    selection = nil
    @spinner.update(title: "Selecting optimal model...")
    @spinner.run do
      selection = ModelSelector.select(plan)
    end

    puts "Task Type: #{plan['task_type']} | Risk: #{plan['risk_level']} | Confidence: #{plan['confidence']}"

    if plan['confidence'].to_f < 0.7
      prompt = TTY::Prompt.new
      choice = prompt.select("Low confidence detected. How should we proceed?",
        "Execute with suggested #{selection[:engine]} (#{selection[:model] || 'default'})",
        "Override and use Claude Opus",
        "Abort task"
      )

      case choice
      when /Override/
        selection = { engine: :claude, model: "opus" }
        puts "Overridden: Using Claude Opus."
      when /Abort/
        puts "Task aborted by user."
        return
      end
    end

    puts "Engine Selected: #{selection[:engine]} (#{selection[:model] || 'default'})"

    if plan['slices']&.any?
      puts "Slices:"
      plan['slices'].each { |s| puts " - #{s}" }
    end

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
    @spinner.update(title: "Running tests...")
    result = nil
    @spinner.run { result = TerminalRunner.run("bundle exec rspec") }

    if result[:exit_status] == 0
      puts "All tests passed! ✅"
      return
    end

    @spinner.update(title: "Tests failed. Summarizing with local Ollama...")
    summary = nil
    @spinner.run { summary = @tiny_processor.summarize_test_output(result[:output]) }

    puts "\n--- Diagnostic Summary ---"
    table = TTY::Table.new(header: ["Attribute", "Value"])
    table << ["Failed Tests", summary['failed_tests'].join("\n")]
    table << ["Error Summary", summary['error_summary']]
    puts table.render(:unicode, multiline: true)

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

    @spinner.update(title: "Applying fix via #{selection[:engine]}...")
    result = nil
    @spinner.run { result = adapter.call(fix_prompt, selection[:model]) }
    puts result

    @spinner.update(title: "Verifying fix...")
    verify_result = nil
    @spinner.run { verify_result = TerminalRunner.run("bundle exec rspec") }

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
