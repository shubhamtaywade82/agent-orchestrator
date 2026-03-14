# frozen_string_literal: true

module Ares
  module SelfImprove
    class RepoAnalyzer
      def analyze(path = ".")
        ContextEngine::Pipeline.build(path)
      end
    end
  end
end
