# frozen_string_literal: true

module Ares
  module TaskGraph
    class ExecutorPool
      def initialize(executor: nil)
        @executor = executor || Orchestrator::Executor.new
      end

      def execute(task)
        @executor.execute(task)
      end
    end
  end
end
