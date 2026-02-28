# frozen_string_literal: true

module Ares
  module Runtime
    class CursorAdapter
      def call(prompt, _model = nil)
        puts "CURSOR ADAPTER: Opening cursor with prompt...\n#{prompt[0..100]}..."
        # In a real environment, this might trigger a local socket or file write
        # for the Cursor agent to pick up.
        'Task handed over to Cursor Agent.'
      end
    end
  end
end
