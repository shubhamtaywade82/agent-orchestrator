# frozen_string_literal: true

module Ares
  module ContextEngine
    class Pipeline
      def self.build(path, summarize_with_ollama: false, code_index: nil)
        new(path, summarize_with_ollama: summarize_with_ollama, code_index: code_index).run
      end

      def self.build_incremental(path, cached: false)
        changed = Context::DiffContext.new.changed_files(path, cached: cached)
        rb_files = changed.select { |f| f.end_with?(".rb") }
        return { compressed: "", files_count: 0 } if rb_files.empty?

        pipeline = new(path, summarize_with_ollama: false, code_index: nil)
        pipeline.run_for_files(rb_files)
      end

      def initialize(path, summarize_with_ollama: false, code_index: nil)
        @path = path
        @summarize_with_ollama = summarize_with_ollama
        @code_index = code_index
      end

      def run
        files = RepoScanner.new.scan(@path)
        run_for_files(files)
      end

      def run_for_files(files)
        symbol_graph = SymbolGraph.new
        dependency_graph = DependencyGraph.new
        summaries = []

        files.each do |file|
          full_path = File.exist?(file) ? file : File.join(@path, file)
          next unless File.exist?(full_path)

          symbols = AstExtractor.new.extract_symbols(full_path)
          next if symbols.empty?

          register_symbols(symbols, symbol_graph, dependency_graph)
          summaries << build_file_summary(full_path, symbols)
        end

        compressed = ContextCompressor.new.compress(summaries, dependency_graph: dependency_graph)
        result = {
          files_count: files.size,
          symbol_graph: symbol_graph.graph,
          dependency_graph: dependency_graph.graph,
          summaries: summaries,
          compressed: compressed
        }
        @code_index&.fill_from_result(result)
        result
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
