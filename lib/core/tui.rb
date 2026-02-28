require 'tty-box'
require 'tty-screen'
require 'tty-cursor'
require 'tty-table'
require 'tty-prompt'
require_relative 'router'
require_relative 'task_logger'
require_relative 'quota_manager'
require_relative 'config_manager'
require_relative '../adapters/ollama_adapter'

module Ares
  module Runtime
    class Tui
      def self.start
        new.run
      end

      def initialize
        @cursor = TTY::Cursor
        @prompt = TTY::Prompt.new(interrupt: :exit)
        @logger = TaskLogger.new
        @router = Router.new
        @log_dir = File.expand_path('../../logs', __dir__)
      end

      def run
        loop do
          render_dashboard
          handle_input
        rescue StandardError => e
          system('clear')
          puts "TUI Error: #{e.message}"
          puts e.backtrace.first(5)
          @prompt.keypress('Press any key to exit...')
          exit 1
        end
      end

      private

      def render_dashboard
        system('clear')
        width = TTY::Screen.width
        height = TTY::Screen.height

        # Header
        header_box = TTY::Box.frame(
          width: width,
          height: 3,
          align: :center,
          padding: 0,
          title: { top_left: " ARES ORCHESTRATOR v#{Ares::Runtime::VERSION} ",
                   bottom_right: " #{Time.now.strftime('%H:%M:%S')} " },
          style: { border: { fg: :cyan } }
        ) { 'Deterministic Multi-Agent Runtime' }
        print header_box

        # Stats & Quota
        stats_box = TTY::Box.frame(
          width: width / 2,
          height: 6,
          top: 3,
          title: { top_left: ' SYSTEM STATS ' },
          style: { border: { fg: :yellow } }
        ) do
          [
            "Claude Quota: #{QuotaManager.usage[:claude]}/#{QuotaManager::LIMITS[:claude]}",
            "Codex Quota:  #{QuotaManager.usage[:codex]}/#{QuotaManager::LIMITS[:codex]}",
            "Tasks Run:    #{Dir.glob(File.join(@log_dir, '*.json')).count}"
          ].join("\n")
        end
        print stats_box

        # Recent History
        history = Dir.glob(File.join(@log_dir, '*.json')).sort_by { |f| File.mtime(f) }.last(3).reverse
        history_box = TTY::Box.frame(
          width: width / 2,
          height: 6,
          top: 3,
          left: width / 2,
          title: { top_left: ' RECENT HISTORY ' },
          style: { border: { fg: :magenta } }
        ) do
          if history.empty?
            'No tasks run yet.'
          else
            history.map { |f| "#{File.basename(f, '.json')[0..20]}..." }.join("\n")
          end
        end
        print history_box

        # Footer / Instructions
        print @cursor.move_to(0, height - 2)
        print 'Press [Enter] to start a new task, [T] to run tests, [L] to lint, [C] to config, [Q] to quit.'
      end

      def handle_input
        case @prompt.keypress('')
        when 'q', 'Q', "\u0003"
          system('clear')
          exit
        when "\r", "\n"
          task = @prompt.ask('Enter task description:')
          return if task.nil? || task.strip.empty?

          begin
            @router.run(task, git: true)
          rescue StandardError => e
            puts "\n❌ Error executing task: #{e.message}"
            puts e.backtrace.first(3).join("\n")
          ensure
            @prompt.keypress('Press any key to return to dashboard...')
          end
        when 't', 'T'
          begin
            @router.run('run tests', git: false)
          rescue StandardError => e
            puts "\n❌ Error running tests: #{e.message}"
          end
        when 'l', 'L'
          begin
            @router.run('lint', git: false)
          rescue StandardError => e
            puts "\n❌ Error during linting: #{e.message}"
          ensure
            @prompt.keypress('Press any key to return to dashboard...')
          end
        when 'c', 'C'
          configure_settings
        end
      end

      def configure_settings
        loop do
          system('clear')
          puts '--- ⚙️ ARES CONFIGURATION MODE ---'

          task_types = ConfigManager.task_types
          task_type = @prompt.select('Select task type to configure:', task_types + ['Exit to Dashboard'])
          break if task_type == 'Exit to Dashboard'

          current_config = ConfigManager.load[task_type]
          puts "\nCurrent config for #{task_type}: #{current_config[:engine]} (#{current_config[:model] || 'default'})"

          engine_options = %w[claude codex cursor ollama] + ['Back']
          engine = @prompt.select('Select engine:', engine_options)
          next if engine == 'Back'

          model = case engine
                  when 'claude'
                    @prompt.select('Select model:', %w[opus sonnet haiku Back])
                  when 'ollama'
                    OllamaAdapter.new.send(:best_available_model) # Trigger discovery
                    available = Ollama::Client.new.list_model_names
                    @prompt.select('Select model (discovered):', available + ['Back'])
                  else
                    @prompt.ask('Enter model name (or leave empty for default, type "back" to cancel):')
                  end

          next if model == 'Back' || model.to_s.downcase == 'back'

          model = nil if model.to_s.strip.empty?

          ConfigManager.update_task_config(task_type, engine, model)
          puts "\n✅ Configuration updated for #{task_type}!"
          sleep 1
        end
      end
    end
  end
end
