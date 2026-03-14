# frozen_string_literal: true

require "json"

module Ares
  module Context
    class TaskCache
      DEFAULT_PATH = ".task_cache.json"
      DEFAULT_TTL = 3600

      def initialize(path: DEFAULT_PATH, ttl: DEFAULT_TTL)
        @path = path
        @ttl = ttl
        @memory = {}
        @file_backed = path
        load
      end

      def get(signature)
        entry = @memory[normalize(signature)]
        return nil unless entry
        return nil if expired?(entry)

        entry[:result]
      end

      def set(signature, result, compressed_context: nil)
        @memory[normalize(signature)] = {
          result: result,
          compressed_context_used: compressed_context,
          at: Time.now.to_i
        }
        save
      end

      def clear
        @memory = {}
        save
      end

      private

      def normalize(signature)
        signature.to_s.strip
      end

      def expired?(entry)
        return false if @ttl <= 0

        (Time.now.to_i - entry[:at]) > @ttl
      end

      def save
        return unless @file_backed

        File.write(@file_backed, JSON.pretty_generate(@memory))
      end

      def load
        return unless @file_backed && File.exist?(@file_backed)

        @memory = JSON.parse(File.read(@file_backed), symbolize_names: true)
      rescue JSON::ParserError
        @memory = {}
      end
    end
  end
end
