# frozen_string_literal: true

module Ares
  module SelfImprove
    class Loop
      def run(path = ".")
        context = RepoAnalyzer.new.analyze(path)
        issues = ImprovementDetector.new.detect(context)
        return { improved: false, reason: "no issues" } if issues.empty?

        plans = ImprovementPlanner.new.plan(issues)
        generator = PatchGenerator.new
        runner = TestRunner.new
        evaluator = Evaluator.new

        plans.each do |plan|
          patch_info = generator.generate(plan)
          runner.run
          next unless runner.success?

          eval_result = evaluator.evaluate(patch_info[:path])
          return { improved: true, plan: plan, patch: patch_info } if eval_result[:approved]
        end

        { improved: false, reason: "no approved patches" }
      end
    end
  end
end
