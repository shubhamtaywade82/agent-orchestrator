# frozen_string_literal: true

module Ares
  module ContextEngine
    class Pipeline
      def self.build(path, summarize_with_ollama: false)
        new(path, summarize_with_ollama: summarize_with_ollama).run
      end

      def initialize(path, summarize_with_ollama: false)
        @path = path
        @summarize_with_ollama = summarize_with_ollama
      end

      def run
        files = RepoScanner.new.scan(@path)
        symbol_graph = SymbolGraph.new
        dependency_graph = DependencyGraph.new
        summaries = []

        files.each do |file|
          symbols = AstExtractor.new.extract_symbols(file)
          next if symbols.empty?

          register_symbols(symbols, symbol_graph, dependency_graph)
          summaries << build_file_summary(file, symbols)
        end

        compressed = ContextCompressor.new.compress(summaries, dependency_graph: dependency_graph)
        {
          files_count: files.size,
          symbol_graph: symbol_graph.graph,
          dependency_graph: dependency_graph.graph,
          summaries: summaries,
          compressed: compressed
        }
      end

      private

      def register_symbols(symbols, symbol_graph, dependency_graph)
        classes = symbols[:classes] || []
        deps = (symbols[:dependencies] || []).uniq

        classes.each do |from|
          deps.each do |to|
            next if from == to

            symbol_graph.add(from, to)
            dependency_graph.add(from, to)
          end
        end
      end

      def build_file_summary(file, symbols)
        if @summarize_with_ollama
          code = File.read(file)
          FileSummarizer.new.summarize(file, code: code, symbols: symbols)
        else
          {
            file: file,
            class: symbols[:classes]&.first,
            responsibility: "see code",
            methods: symbols[:methods] || [],
            dependencies: symbols[:dependencies]&.uniq || []
          }
        end
      end
    end
  end
end
