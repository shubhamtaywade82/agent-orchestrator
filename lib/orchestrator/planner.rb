# frozen_string_literal: true

module Ares
  module Orchestrator
    class Planner
      def plan(input)
        graph = TaskGraph::Graph.new
        s = input.to_s.strip

        if s.match?(/^\s*build\s+/i)
          build_plan(graph, s)
        else
          default_plan(graph)
        end
      end

      def default_plan(graph)
        scan = Task.new(type: :scan_repo, payload: ".")
        context = Task.new(type: :build_context, payload: ".")
        graph.add(scan)
        graph.add(context, depends_on: scan)
        graph
      end

      def build_plan(graph, input)
        arch = Task.new(type: :architecture, payload: input)
        code = Task.new(type: :code_generation, payload: input)
        tests = Task.new(type: :code_generation, payload: "#{input} (write tests)")
        review = Task.new(type: :architecture, payload: "Review: #{input}")

        graph.add(arch)
        graph.add(code, depends_on: arch)
        graph.add(tests, depends_on: code)
        graph.add(review, depends_on: tests)
        graph
      end
    end
  end
end
