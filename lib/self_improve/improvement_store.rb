# frozen_string_literal: true

require "fileutils"
require "json"

module Ares
  module SelfImprove
    class ImprovementStore
      DEFAULT_PATH = "ares_tasks/self_improvements.json"

      def initialize(path: DEFAULT_PATH)
        @path = path
        @tasks = load
      end

      def append(type:, target:, goal:, status: "pending")
        @tasks << { type: type, target: target, goal: goal, status: status }
        save
      end

      def by_target(target)
        @tasks.select { |t| t[:target].to_s.include?(target.to_s) }
      end

      def pending
        @tasks.select { |t| t[:status] == "pending" }
      end

      def save
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(@tasks))
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
