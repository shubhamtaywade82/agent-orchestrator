# frozen_string_literal: true

module Ares
  module Runtime
    class Doctor
      def self.run
        puts "Running Ares diagnostics...\n\n"

        check_ollama
        check_claude
        check_codex
        check_cursor

        puts "\nDiagnostics complete."
      end

      def self.check_ollama
        puts "Ollama: #{system('which ollama > /dev/null') ? 'OK' : 'Missing'}"
      end

      def self.check_claude
        puts "Claude CLI: #{system('which claude > /dev/null') ? 'OK' : 'Missing'}"
      end

      def self.check_codex
        puts "Codex CLI: #{system('which codex > /dev/null') ? 'OK' : 'Missing'}"
      end

      def self.check_cursor
        puts "Cursor CLI: #{system('which cursor > /dev/null') ? 'OK' : 'Missing'}"
      end
    end
  end
end
