# frozen_string_literal: true

module Ares
  module SelfImprove
    class ImprovementDetector
      def detect(context)
        issues = []

        issues << "router optimization" if router_static?(context)
        issues << "duplicate logic" if duplicate_logic?(context)
        issues << "large classes" if large_classes?(context)
        issues << "unused code" if unused_code?(context)

        issues
      end

      private

      def router_static?(context)
        g = context[:dependency_graph] || {}
        g.key?("Router") && (g["Router"] || []).size < 3
      end

      def duplicate_logic?(context)
        summaries = context[:summaries] || []
        responsibilities = summaries.map { |s| s[:responsibility] }.compact
        responsibilities.size != responsibilities.uniq.size
      end

      def large_classes?(context)
        summaries = context[:summaries] || []
        summaries.any? { |s| (s[:methods] || []).size > 15 }
      end

      def unused_code?(context)
        g = context[:dependency_graph] || {}
        return false if g.empty?

        referenced = g.values.flatten.uniq
        defined = g.keys
        (defined - referenced).size > 2
      end
    end
  end
end
