# frozen_string_literal: true

require "securerandom"

module Ares
  module Orchestrator
    class Task
      attr_reader :id, :type, :payload

      def initialize(type:, payload:)
        @id = SecureRandom.uuid
        @type = type
        @payload = payload
      end
    end
  end
end
