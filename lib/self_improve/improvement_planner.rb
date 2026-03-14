# frozen_string_literal: true

module Ares
  module SelfImprove
    class ImprovementPlanner
      def plan(issues)
        issues.map { |issue| { issue: issue, path: target_path(issue) } }
      end

      private

      def target_path(issue)
        case issue
        when /router/ then "lib/orchestrator/router.rb"
        when /duplicate/ then "lib"
        when /large/ then "lib"
        when /unused/ then "lib"
        else "lib"
        end
      end
    end
  end
end
