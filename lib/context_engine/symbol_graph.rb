# frozen_string_literal: true

module Ares
  module ContextEngine
    class SymbolGraph
      def initialize
        @graph = {}
      end

      def add(from, to)
        @graph[from] ||= []
        @graph[from] << to unless @graph[from].include?(to)
      end

      def graph
        @graph
      end
    end
  end
end
