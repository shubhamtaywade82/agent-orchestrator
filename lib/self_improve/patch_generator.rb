# frozen_string_literal: true

require "fileutils"

module Ares
  module SelfImprove
    class PatchGenerator
      def initialize(experiment_dir: "experiments")
        @experiment_dir = experiment_dir
      end

      def generate(improvement_plan)
        path = improvement_plan[:path]
        issue = improvement_plan[:issue]
        dir = "#{@experiment_dir}/#{File.basename(path, '.rb')}_v2"
        FileUtils.mkdir_p(File.dirname(dir))
        { experiment_dir: dir, path: path, issue: issue }
      end
    end
  end
end
