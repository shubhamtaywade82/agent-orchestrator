# frozen_string_literal: true

module Ares
  module ContextEngine
    class RepoScanner
      def scan(path)
        Dir.glob("#{path}/**/*.rb")
      end
    end
  end
end
