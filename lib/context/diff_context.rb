# frozen_string_literal: true

module Ares
  module Context
    class DiffContext
      def changed_files(repo_path = ".", cached: false)
        diff = run_diff(repo_path, cached: cached)
        parse_changed_files(diff)
      end

      def patch(repo_path = ".", cached: false)
        run_diff(repo_path, cached: cached)
      end

      private

      def run_diff(repo_path, cached: false)
        cmd = cached ? "git diff --cached" : "git diff"
        Dir.chdir(repo_path) { `#{cmd}` }
      end

      def parse_changed_files(diff)
        paths = []
        diff.each_line do |line|
          next unless line.start_with?("+++ b/", "--- a/")

          path = line.sub(/\A\+\+\+ b\//, "").sub(/\A--- a\//, "").strip
          paths << path unless path == "/dev/null"
        end
        paths.uniq
      end
    end
  end
end
