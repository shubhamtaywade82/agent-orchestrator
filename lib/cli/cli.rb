# frozen_string_literal: true

require "thor"
require "json"

module Ares
  class CLI < Thor
    desc "task TASK", "Run a development task"
    def task(cmd)
      planner = Orchestrator::Planner.new
      graph = planner.plan(cmd)

      scheduler = TaskGraph::Scheduler.new
      scheduler.run(graph)
    end

    desc "plan INPUT", "Write a task plan to plan.json"
    def plan(input)
      planner = Orchestrator::Planner.new
      graph = planner.plan(input)
      plan_data = graph.to_plan.map { |h| h.transform_keys(&:to_s) }
      File.write("plan.json", JSON.pretty_generate(plan_data))
      puts "Wrote plan.json (#{plan_data.size} tasks)"
    end

    desc "execute PLAN_JSON", "Run a plan from plan.json"
    def execute(plan_path = "plan.json")
      unless File.exist?(plan_path)
        puts "No such file: #{plan_path}"
        exit 1
      end
      plan_data = JSON.parse(File.read(plan_path))
      graph = TaskGraph::Graph.from_plan(plan_data)
      scheduler = TaskGraph::ParallelScheduler.new
      merged = scheduler.run(graph)
      puts "Merged #{merged[:files]&.size || 0} file(s), #{merged[:merged]&.size || 0} result(s)"
    end

    desc "review [PATH]", "Run context engine and review (stub)"
    def review(path = ".")
      result = ContextEngine::Pipeline.build(path)
      puts result[:compressed]
      puts "\n[Review task would be sent to Claude with above context]"
    end

    desc "improve [TARGET]", "Run self-improvement loop (optional TARGET e.g. router)"
    method_option :review, type: :boolean, default: false, desc: "Pause for human approval before merge"
    def improve(target = nil)
      result = SelfImprove::Loop.new.run(".", target: target, review: options[:review])
      if result[:improved]
        puts "Improved: #{result[:plan]}"
      else
        puts result[:reason] || "No changes applied"
      end
    end
  end
end
