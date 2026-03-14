# frozen_string_literal: true

require "json"

module Ares
  module Context
    class CodeIndex
      DEFAULT_PATH = ".context_index.json"

      def initialize(path: DEFAULT_PATH)
        @path = path
        @index = load
      end

      def index_class(name, data)
        @index[name] = data
      end

      def lookup(name)
        @index[name.to_s]
      end

      def lookup_file(file_path)
        @index.find { |_k, v| v["file"] == file_path || v[:file] == file_path }&.last
      end

      def fill_from_result(result)
        (result[:summaries] || []).each do |s|
          name = s[:class] || File.basename(s[:file], ".rb")
          next if name.to_s.empty?

          index_class(name.to_s, "file" => s[:file], "methods" => (s[:methods] || []), "dependencies" => (s[:dependencies] || []))
        end
        save
        @index
      end

      def refresh(repo_path)
        ContextEngine::Pipeline.build(repo_path, code_index: self)
        @index
      end

      def save
        File.write(@path, JSON.pretty_generate(@index.transform_keys(&:to_s)))
      end

      def load
        return {} unless File.exist?(@path)

        raw = JSON.parse(File.read(@path))
        raw.each_with_object({}) { |(k, v), h| h[k.to_s] = v.transform_keys(&:to_s) if v.is_a?(Hash) }
      rescue JSON::ParserError
        {}
      end
    end
  end
end
