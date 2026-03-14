# frozen_string_literal: true

module Ares
  module TaskGraph
    class Graph
      attr_reader :nodes

      def initialize
        @nodes = []
      end

      def add(task, depends_on: nil)
        deps = Array(depends_on).compact.map { |t| node_for_task(t) }.compact
        node = Node.new(task, deps)
        @nodes << node
        node
      end

      def add_node(node)
        @nodes << node
        node
      end

      private

      def node_for_task(task)
        @nodes.find { |n| n.task == task }
      end
    end
  end
end
