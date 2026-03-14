# frozen_string_literal: true

module Ares
  module SelfImprove
    class TestRunner
      def run
        system("bundle exec rspec")
      end

      def success?
        $?.success?
      end
    end
  end
end
