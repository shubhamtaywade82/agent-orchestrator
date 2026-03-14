# frozen_string_literal: true

module Ares
  module SelfImprove
    class PatchValidator
      DEFAULT_MAX_LINES = 300

      def initialize(max_lines: DEFAULT_MAX_LINES)
        @max_lines = max_lines
      end

      def valid?(patch_path_or_content)
        size = patch_size(patch_path_or_content)
        size <= @max_lines && size >= 0
      end

      def patch_size(patch_path_or_content)
        return -1 if patch_path_or_content.nil?

        path = patch_path_or_content.to_s
        if File.directory?(path)
          Dir.glob("#{path}/**/*").sum { |f| File.file?(f) ? File.read(f).lines.size : 0 }
        elsif File.exist?(path)
          File.read(path).lines.size
        else
          path.lines.size
        end
      end
    end
  end
end
