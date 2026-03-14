# frozen_string_literal: true

module Ares
  module Context
    class SymbolGraph
      def initialize
        @graph = {}
      end

      def add(from, to)
        @graph[from] ||= []
        @graph[from] << to
      end

      def graph
        @graph
      end
    end
  end
end
