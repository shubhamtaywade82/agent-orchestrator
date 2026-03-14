# frozen_string_literal: true

module Ares
  module TaskGraph
    class Node
      attr_reader :task, :dependencies
      attr_accessor :completed

      def initialize(task, dependencies = [])
        @task = task
        @dependencies = Array(dependencies).compact
        @completed = false
      end

      def ready?
        dependencies.all?(&:completed)
      end
    end
  end
end
