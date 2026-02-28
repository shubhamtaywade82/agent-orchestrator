require "tty-box"
require "tty-screen"
require "tty-cursor"
require "tty-table"
require "tty-prompt"
require_relative "router"
require_relative "task_logger"
require_relative "quota_manager"

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
        @log_dir = File.expand_path("../../logs", __dir__)
      end

      def run
        loop do
          render_dashboard
          handle_input
        rescue StandardError => e
          system("clear")
          puts "TUI Error: #{e.message}"
          puts e.backtrace.first(5)
          @prompt.keypress("Press any key to exit...")
          exit 1
        end
      end

      private

      def render_dashboard
        system("clear")
        width = TTY::Screen.width
        height = TTY::Screen.height

        # Header
        header_box = TTY::Box.frame(
          width: width,
          height: 3,
          align: :center,
          padding: 0,
          title: { top_left: " ARES ORCHESTRATOR v#{Ares::Runtime::VERSION} ", bottom_right: " #{Time.now.strftime('%H:%M:%S')} " },
          style: { border: { fg: :cyan } }
        ) { "Deterministic Multi-Agent Runtime" }
        print header_box

        # Stats & Quota
        stats_box = TTY::Box.frame(
          width: width / 2,
          height: 6,
          top: 3,
          title: { top_left: " SYSTEM STATS " },
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
        history = Dir.glob(File.join(@log_dir, "*.json")).sort_by { |f| File.mtime(f) }.reverse.first(3)
        history_box = TTY::Box.frame(
          width: width / 2,
          height: 6,
          top: 3,
          left: width / 2,
          title: { top_left: " RECENT HISTORY " },
          style: { border: { fg: :magenta } }
        ) do
          if history.empty?
            "No tasks run yet."
          else
            history.map { |f| File.basename(f, ".json")[0..20] + "..." }.join("\n")
          end
        end
        print history_box

        # Footer / Instructions
        print @cursor.move_to(0, height - 1)
        print "Press [Enter] to start a new task, [T] to run tests, [Q] to quit."
      end

      def handle_input
        case @prompt.keypress("")
        when "q", "Q", "\u0003"
          system("clear")
          exit
        when "t", "T"
          @router.run("run tests")
          @prompt.keypress("Press any key to return to dashboard...")
        when "\r"
          task = @prompt.ask("Enter task description:")
          if task && !task.empty?
            @router.run(task)
            @prompt.keypress("Press any key to return to dashboard...")
          end
        end
      end
    end
  end
end
