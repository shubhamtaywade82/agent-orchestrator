# frozen_string_literal: true

require_relative 'ares/runtime/version'

# Core
require_relative 'ares/runtime/config_manager'
require_relative 'ares/runtime/context_loader'
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
require_relative 'adapters/claude_adapter'
require_relative 'adapters/codex_adapter'
require_relative 'adapters/cursor_adapter'
require_relative 'adapters/ollama_adapter'

# Runtime CLI Commands
require_relative 'ares/runtime'
require_relative 'ares/cli'
require_relative 'ares/runtime/config_cli'
require_relative 'ares/runtime/doctor'
require_relative 'ares/runtime/initializer'
require_relative 'ares/runtime/logs_cli'

# Alias for convenience if needed
module Ares
  # The Ares Orchestrator Runtime
end
