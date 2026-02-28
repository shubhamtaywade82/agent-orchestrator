# frozen_string_literal: true

require_relative 'adapters/claude_adapter'
require_relative 'adapters/codex_adapter'
require_relative 'adapters/cursor_adapter'
require_relative 'adapters/ollama_adapter'

module Ares
  module Runtime
    # Chain of Responsibility Handler linking CLI engines for automated fallback.
    class EngineChain
      attr_accessor :next_handler
      attr_reader :engine_name

      def initialize(engine_name)
        @engine_name = engine_name
        @next_handler = nil
        @adapter = get_adapter(engine_name)
      end

      # Standard execution chain
      def call(prompt, options, attempt: 1, total: 1)
        if attempt > 1
          puts "Falling back to #{@engine_name} (attempt #{attempt}/#{total})..."
        else
          puts "Executing task via #{@engine_name} (attempt #{attempt}/#{total})..."
        end

        begin
          QuotaManager.increment_usage(@engine_name)

          @adapter.call(prompt, options[:model], **adapter_options(options))
        rescue StandardError => e
          puts "\n⚠️ #{@engine_name} failed: #{e.message.split("\n").first}"

          raise 'All available AI engines failed to execute the task.' unless @next_handler

          @next_handler.call(prompt, options, attempt: attempt + 1, total: total)
        end
      end

      # Specialized call for fix escalation
      def call_fix(prompt, options, attempt: 1, total: 1, &checkpoint_block)
        if attempt > 1
          puts "Falling back to #{@engine_name} for fix (attempt #{attempt}/#{total})..."
        else
          puts "Applying fix via #{@engine_name} (attempt #{attempt}/#{total})..."
        end

        checkpoint_block&.call(@engine_name)

        begin
          QuotaManager.increment_usage(@engine_name)

          @adapter.call(prompt, options[:model], **adapter_options(options))
        rescue StandardError => e
          puts "\n⚠️ #{@engine_name} failed during fix: #{e.message.split("\n").first}"

          raise 'All available AI engines failed to apply the fix.' unless @next_handler

          @next_handler.call_fix(prompt, options, attempt: attempt + 1, total: total, &checkpoint_block)
        end
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
