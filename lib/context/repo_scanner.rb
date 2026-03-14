# frozen_string_literal: true

module Ares
  module Context
    class RepoScanner
      def scan(path)
        Dir.glob("#{path}/**/*.rb")
      end
    end
  end
end
