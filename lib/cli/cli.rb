# frozen_string_literal: true

require "thor"

module Ares
  class CLI < Thor
    desc "task TASK", "Run a development task"

    def task(cmd)
      planner = Orchestrator::Planner.new
      graph = planner.plan(cmd)

      scheduler = TaskGraph::Scheduler.new
      scheduler.run(graph)
    end
  end
end
