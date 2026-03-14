# frozen_string_literal: true

module Ares
  module TaskGraph
    class ParallelScheduler
      def initialize(executor_pool: nil, reducer: nil)
        @pool = executor_pool || ExecutorPool.new
        @reducer = reducer || Orchestrator::Reducer.new
      end

      def run(graph)
        results = []
        mutex = Mutex.new

        until all_done?(graph)
          ready = graph.nodes.select { |n| !n.completed && n.ready? }
          break if ready.empty?

          threads = ready.map do |node|
            Thread.new do
              out = @pool.execute(node.task)
              mutex.synchronize { results << out }
              node.completed = true
            end
          end
          threads.each(&:join)
        end

        @reducer.merge(results)
      end

      private

      def all_done?(graph)
        graph.nodes.all?(&:completed)
      end
    end
  end
end
