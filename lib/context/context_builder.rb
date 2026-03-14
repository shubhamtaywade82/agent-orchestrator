# frozen_string_literal: true

module Ares
  module Context
    class ContextBuilder
      def build(path)
        files = RepoScanner.new.scan(path)

        files.each do |file|
          AstExtractor.new.extract(file)
        end

        files
      end
    end
  end
end
