# frozen_string_literal: true

require "fileutils"

module Ares
  module SelfImprove
    class PatchGenerator
      def generate(improvement_plan, experiment_dir: "experiments")
        path = improvement_plan[:path]
        issue = improvement_plan[:issue]
        dir = "#{experiment_dir}/#{File.basename(path, '.rb')}_v2"
        FileUtils.mkdir_p(File.dirname(dir))
        { experiment_dir: dir, path: path, issue: issue }
      end
    end
  end
end
