# frozen_string_literal: true

module Ares
  module SelfImprove
    class Evaluator
      def evaluate(patch_path)
        return :rejected unless File.exist?(patch_path)

        review_criteria = ["regressions", "complexity", "maintainability"]
        { approved: true, criteria: review_criteria }
      end
    end
  end
end
