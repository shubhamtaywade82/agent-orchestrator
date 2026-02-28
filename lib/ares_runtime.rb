# frozen_string_literal: true

require 'tty-spinner'
require 'tty-prompt'
require 'tty-table'
require 'tty-box'
require 'tty-screen'
require 'tty-cursor'
require 'tty-command'
require 'dotenv'
require 'json'
require 'yaml'
require 'fileutils'
require 'securerandom'

# Load Dotenv
begin
  Dotenv.load
rescue StandardError
  nil
end

require_relative 'ares/runtime/version'

# Core
require_relative 'ares/runtime/config_manager'
require_relative 'ares/runtime/context_loader'
require_relative 'ares/runtime/diagnostic_parser'
require_relative 'ares/runtime/git_manager'
require_relative 'ares/runtime/model_selector'
require_relative 'ares/runtime/quota_manager'
require_relative 'ares/runtime/router'
require_relative 'ares/runtime/task_logger'
require_relative 'ares/runtime/task_manager'
require_relative 'ares/runtime/terminal_runner'
require_relative 'ares/runtime/tui'

# Planner
require_relative 'ares/runtime/planner/ollama_planner'
require_relative 'ares/runtime/planner/tiny_task_processor'

# Adapters
require_relative 'ares/runtime/adapters/claude_adapter'
require_relative 'ares/runtime/adapters/codex_adapter'
require_relative 'ares/runtime/adapters/cursor_adapter'
require_relative 'ares/runtime/adapters/ollama_adapter'

# Runtime CLI Commands
require_relative 'ares/runtime'
require_relative 'ares/cli'
require_relative 'ares/runtime/config_cli'
require_relative 'ares/runtime/doctor'
require_relative 'ares/runtime/initializer'
require_relative 'ares/runtime/logs_cli'

# The Ares Orchestrator Runtime
module Ares
  # Root namespace for the Ares Orchestrator CLI.
  # All core logic is contained within Ares::Runtime.
end
