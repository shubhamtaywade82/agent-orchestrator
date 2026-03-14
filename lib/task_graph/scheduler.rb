# frozen_string_literal: true

module Ares
  module TaskGraph
    class Scheduler
      def run(graph)
        executor = Orchestrator::Executor.new

        graph.nodes.each do |node|
          next unless node.ready?

          executor.execute(node.task)
          node.completed = true
        end
      end
    end
  end
end
