# frozen_string_literal: true

module Ares
  module Orchestrator
    class Planner
      def plan(input)
        graph = TaskGraph::Graph.new

        scan = Task.new(type: :scan_repo, payload: ".")
        context = Task.new(type: :build_context, payload: ".")

        graph.add(scan)
        graph.add(context, depends_on: scan)

        graph
      end
    end
  end
end
