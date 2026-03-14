# frozen_string_literal: true

module Ares
  module SelfImprove
    class Loop
      SANDBOX_DIR = "experiments"

      def initialize(improvement_store: nil, patch_validator: nil)
        @store = improvement_store || ImprovementStore.new
        @validator = patch_validator || PatchValidator.new
      end

      def run(path = ".", target: nil, review: false)
        context = RepoAnalyzer.new.analyze(path)
        issues = ImprovementDetector.new.detect(context)
        return { improved: false, reason: "no issues" } if issues.empty?

        plans = ImprovementPlanner.new.plan(issues)
        plans.each { |p| @store.append(type: p[:issue], target: p[:path], goal: p[:issue]) }
        plans = filter_by_target(plans, target) if target

        generator = PatchGenerator.new(experiment_dir: SANDBOX_DIR)
        runner = TestRunner.new
        evaluator = Evaluator.new

        plans.each do |plan|
          next unless sandboxed?(plan)

          patch_info = generator.generate(plan)
          runner.run
          next unless runner.success?

          next unless @validator.valid?(patch_info[:experiment_dir])

          if review && !approved_by_user?(patch_info)
            next
          end

          eval_result = evaluator.evaluate(patch_info[:experiment_dir])
          return { improved: true, plan: plan, patch: patch_info } if eval_result[:approved]
        end

        { improved: false, reason: "no approved patches" }
      end

      private

      def filter_by_target(plans, target)
        plans.select { |p| p[:path].to_s.include?(target.to_s) }
      end

      def sandboxed?(plan)
        plan[:path].to_s.start_with?("lib/", "lib\\") && !plan[:path].to_s.include?("../")
      end

      def approved_by_user?(patch_info)
        puts "Patch at #{patch_info[:experiment_dir]}. Approve? [y/N]"
        $stdin.gets&.strip&.downcase == "y"
      end
    end
  end
end
