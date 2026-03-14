# frozen_string_literal: true

module Ares
  module TaskGraph
    class ParallelScheduler
      def initialize(executor_pool: nil)
        @pool = executor_pool || ExecutorPool.new
      end

      def run(graph)
        until all_done?(graph)
          ready = graph.nodes.select { |n| !n.completed && n.ready? }
          break if ready.empty?

          threads = ready.map do |node|
            Thread.new do
              @pool.execute(node.task)
              node.completed = true
            end
          end
          threads.each(&:join)
        end
      end

      private

      def all_done?(graph)
        graph.nodes.all?(&:completed)
      end
    end
  end
end
