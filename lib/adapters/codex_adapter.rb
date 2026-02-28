# frozen_string_literal: true

module Ares
  module Runtime
    class CodexAdapter
      def call(prompt, _model = nil)
        cmd = %w[codex exec]
        output = IO.popen(cmd, 'r+') do |io|
          io.write(prompt)
          io.close_write
          io.read
        end
        raise "Codex command failed: #{output}" unless $CHILD_STATUS.success?

        output
      end

      # Removed escape method as we now use stdin
    end
  end
end
