# frozen_string_literal: true

module Ares
  module ContextEngine
    class ContextCompressor
      def compress(summaries, dependency_graph:)
        sections = []
        sections << format_controllers(summaries)
        sections << format_services(summaries)
        sections << format_dependencies(dependency_graph)
        sections.compact.join("\n\n")
      end

      private

      def format_controllers(summaries)
        controllers = summaries.select { |s| controller?(s) }
        return nil if controllers.empty?

        lines = controllers.map { |s| "#{s[:class]}: #{s[:responsibility]}" }
        "Controllers\n" + lines.map { |l| "- #{l}" }.join("\n")
      end

      def format_services(summaries)
        services = summaries.reject { |s| controller?(s) }
        return nil if services.empty?

        lines = services.map { |s| "#{s[:class] || File.basename(s[:file], '.rb')} (#{s[:responsibility]})" }
        "Services / Components\n" + lines.map { |l| "- #{l}" }.join("\n")
      end

      def format_dependencies(dependency_graph)
        g = dependency_graph.graph
        return nil if g.empty?

        lines = g.flat_map { |from, tos| tos.map { |to| "#{from} → #{to}" } }.uniq
        "Dependencies\n" + lines.map { |l| "- #{l}" }.join("\n")
      end

      def controller?(summary)
        name = (summary[:class] || "").to_s
        name.end_with?("Controller")
      end
    end
  end
end
