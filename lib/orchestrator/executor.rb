# frozen_string_literal: true

module Ares
  module Orchestrator
    class Executor
      AGENT_TYPES = %i[architecture code_generation repo_analysis file_edit].freeze
      BUILTIN_TYPES = %i[scan_repo build_context compress_context].freeze

      def initialize(router: nil, task_cache: nil, incremental: false)
        @router = router || Router.new
        @task_cache = task_cache
        @incremental = incremental
      end

      def execute(task, incremental: nil)
        use_incremental = incremental != nil ? incremental : @incremental
        if AGENT_TYPES.include?(task.type)
          execute_via_agent(task, incremental: use_incremental)
        else
          execute_builtin(task)
        end
      end

      private

      def task_signature(task)
        "#{task.type}:#{task.payload}"
      end

      def execute_via_agent(task, incremental: false)
        if @task_cache
          cached = @task_cache.get(task_signature(task))
          return { task_id: task.id, type: task.type, result: cached } if cached
        end

        agent_or_local = @router.route(task)
        return { task_id: task.id, type: task.type, result: nil } if agent_or_local.nil?

        context = incremental ? ContextEngine::Pipeline.build_incremental(task.payload.to_s) : nil

        result = if agent_or_local == :local
          LocalAI::Summarizer.new.summarize(task.payload.to_s)
        else
          agent_or_local.run(task, context: context)
        end

        @task_cache&.set(task_signature(task), result)
        { task_id: task.id, type: task.type, result: result }
      end

      def execute_builtin(task)
        raw = case task.type
              when :scan_repo
                files = Context::RepoScanner.new.scan(task.payload)
                puts "Found #{files.size} ruby files"
                files.each { |f| puts "  #{f}" }
                files
              when :build_context
                files = Context::ContextBuilder.new.build(task.payload)
                puts "Built context for #{files.size} files"
                files.each { |f| puts "  #{f}" }
                files
              when :compress_context
                result = ContextEngine::Pipeline.build(task.payload)
                puts result[:compressed]
                result
              else
                puts "Unknown task #{task.type}"
                nil
              end
        { task_id: task.id, type: task.type, result: raw }
      end
    end
  end
end
