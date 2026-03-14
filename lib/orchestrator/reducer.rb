# frozen_string_literal: true

module Ares
  module Orchestrator
    class Reducer
      def merge(task_results)
        return { files: [], merged: {} } if task_results.nil? || task_results.empty?

        files = []
        merged = {}

        task_results.each do |tr|
          task_id = tr[:task_id]
          type = tr[:type]
          result = tr[:result]
          next if result.nil?

          if result.is_a?(Hash) && result[:files]
            result[:files].each { |f| files << f.merge(task_id: task_id, task_type: type) }
          elsif result.is_a?(Hash) && result[:path]
            files << { path: result[:path], content: result[:content] }.merge(task_id: task_id, task_type: type)
          elsif result.is_a?(Array)
            result.each { |r| files << (r.is_a?(Hash) ? r.merge(task_id: task_id, task_type: type) : { path: nil, content: r, task_id: task_id, task_type: type }) }
          else
            merged[task_id] = { type: type, result: result }
          end
        end

        { files: files, merged: merged }
      end
    end
  end
end
