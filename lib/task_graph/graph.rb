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

      def to_plan
        @nodes.map do |n|
          {
            id: n.task.id,
            type: n.task.type,
            payload: n.task.payload,
            depends_on: n.dependencies.map { |d| d.task.id }
          }
        end
      end

      def self.from_plan(plan_array)
        graph = new
        tasks_by_id = {}
        plan_array.each do |h|
          task = Orchestrator::Task.new(type: (h["type"] || h[:type]).to_sym, payload: h["payload"] || h[:payload], id: h["id"] || h[:id])
          tasks_by_id[task.id] = task
        end
        ordered = topo_sort(plan_array)
        ordered.each do |h|
          task = tasks_by_id[h["id"] || h[:id]]
          deps = (h["depends_on"] || h[:depends_on] || []).map { |id| tasks_by_id[id] }.compact
          graph.add(task, depends_on: deps.empty? ? nil : deps)
        end
        graph
      end

      def self.topo_sort(plan_array)
        id_to_deps = plan_array.to_h { |h| [h["id"] || h[:id], (h["depends_on"] || h[:depends_on] || [])] }
        result = []
        visited = {}
        visit = ->(id) do
          return if visited[id]
          visited[id] = true
          (id_to_deps[id] || []).each(&visit)
          result << plan_array.find { |h| (h["id"] || h[:id]) == id }
        end
        plan_array.each { |h| visit.call(h["id"] || h[:id]) }
        result
      end

      private

      def node_for_task(task)
        @nodes.find { |n| n.task == task }
      end
    end
  end
end
