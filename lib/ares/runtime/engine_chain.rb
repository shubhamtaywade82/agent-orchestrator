# frozen_string_literal: true

require_relative 'adapters/claude_adapter'
require_relative 'adapters/codex_adapter'
require_relative 'adapters/cursor_adapter'
require_relative 'adapters/ollama_adapter'

module Ares
  module Runtime
    # Chain of Responsibility Handler linking CLI engines for automated fallback.
    class EngineChain
      CAPABLE_ENGINES = %w[claude codex cursor ollama].freeze

      attr_accessor :next_handler
      attr_reader :engine_name

      def self.build_fallback(initial_engine)
        initial = initial_engine.to_s
        fallback_order = ([initial] + (CAPABLE_ENGINES - [initial])).uniq
        chain = build(fallback_order)
        { chain: chain, size: fallback_order.size }
      end

      def initialize(engine_name)
        @engine_name = engine_name
        @next_handler = nil
        @adapter = get_adapter(engine_name)
      end

      def call(prompt, options, attempt: 1, total: 1)
        execute_with_fallback(prompt, options, attempt, total, mode: :task)
      end

      def call_fix(prompt, options, attempt: 1, total: 1, &block)
        execute_with_fallback(prompt, options, attempt, total, mode: :fix, &block)
      end

      # Factory method to build the chain
      def self.build(engine_names)
        return nil if engine_names.empty?

        first_handler = new(engine_names.first)
        current = first_handler

        engine_names[1..].each do |name|
          handler = new(name)
          current.next_handler = handler
          current = handler
        end

        first_handler
      end

      private

      def execute_with_fallback(prompt, options, attempt, total, mode:, &block)
        puts status_message(attempt, total, mode)
        block&.call(@engine_name)

        QuotaManager.increment_usage(@engine_name)
        opts = adapter_options(options)
        opts[:schema] = options[:schema] if options[:schema]
        @adapter.call(prompt, options[:model], **opts)
      rescue StandardError => e
        failed_msg = mode == :fix ? "#{@engine_name} failed during fix:" : "#{@engine_name} failed:"
        puts "\n❌ #{failed_msg} #{e.message.split("\n").first}"
        raise all_engines_failed_message(mode) unless @next_handler

        next_method = mode == :fix ? :call_fix : :call
        @next_handler.public_send(next_method, prompt, options, attempt: attempt + 1, total: total, &block)
      end

      def status_message(attempt, total, mode)
        action = if attempt > 1
                   'Falling back to'
                 elsif mode == :fix
                   'Applying fix via'
                 else
                   'Executing task via'
                 end
        "#{action} #{@engine_name} (attempt #{attempt}/#{total})..."
      end

      def all_engines_failed_message(mode)
        if mode == :fix
          'All available AI engines failed to apply the fix.'
        else
          'All available AI engines failed to execute the task.'
        end
      end

      def get_adapter(engine)
        case engine
        when 'claude' then Ares::Runtime::ClaudeAdapter.new
        when 'cursor' then Ares::Runtime::CursorAdapter.new
        when 'codex'  then Ares::Runtime::CodexAdapter.new
        when 'ollama' then Ares::Runtime::OllamaAdapter.new
        else raise "Unknown engine: #{engine}"
        end
      end

      def adapter_options(options)
        opts = {}
        case @engine_name
        when 'claude'
          opts[:fork_session] = options[:fork_session] if options.key?(:fork_session)
        when 'cursor'
          opts[:resume] = options.fetch(:resume, true)
          opts[:cloud] = options[:cloud] if options.key?(:cloud)
        when 'codex'
          opts[:resume] = options.fetch(:resume, true)
        end
        opts
      end
    end
  end
end
