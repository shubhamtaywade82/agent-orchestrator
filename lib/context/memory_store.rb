# frozen_string_literal: true

require "json"

module Ares
  module Context
    class MemoryStore
      DEFAULT_PATH = "memory_store.json"

      def initialize(path: DEFAULT_PATH)
        @path = path
        @entries = load
      end

      def append(task_id, type, payload, summary: nil)
        @entries << {
          task_id: task_id,
          type: type,
          payload: payload,
          summary: summary,
          at: Time.now.iso8601
        }
        save
      end

      def recent(limit = 50)
        @entries.last(limit).reverse
      end

      def save
        File.write(@path, JSON.pretty_generate(@entries))
      end

      def load
        return [] unless File.exist?(@path)

        JSON.parse(File.read(@path), symbolize_names: true)
      rescue JSON::ParserError
        []
      end
    end
  end
end
