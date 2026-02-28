# frozen_string_literal: true

module Ares
  module Runtime
    class TaskLogger
      attr_reader :task_id

      def initialize
        @task_id = SecureRandom.uuid
        @log_dir = File.join(ConfigManager.project_root, 'logs')
        FileUtils.mkdir_p(@log_dir)
      end

      def log_task(task, plan, selection)
        log_file = File.join(@log_dir, "#{@task_id}.json")
        data = {
          task_id: @task_id,
          timestamp: Time.now.iso8601,
          task: task,
          plan: plan,
          selection: selection
        }
        File.write(log_file, JSON.pretty_generate(data))
      end

      def log_result(result)
        log_file = File.join(@log_dir, "#{@task_id}.json")
        return unless File.exist?(log_file)

        data = JSON.parse(File.read(log_file))
        data[:result] = result
        data[:completed_at] = Time.now.iso8601
        File.write(log_file, JSON.pretty_generate(data))
      end
    end
  end
end
