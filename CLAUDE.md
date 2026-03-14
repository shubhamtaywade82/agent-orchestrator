# agent-orchestrator (Ares 2.0)

Ruby gem/CLI — multi-agent orchestrator that routes coding tasks to the right LLM engine (Claude, Codex, Cursor, Ollama) based on task type and risk level.

## Stack

- Ruby gem + CLI (`exe/ares`)
- `ollama-client` gem (git source)
- `tty-*` gems (prompt, spinner, table, box, cursor, screen, command)
- `concurrent-ruby`
- RSpec + RuboCop
- Config: YAML in `config/` (`models.yml`, `ollama.yml`, `workspaces.yml`)

## Commands

```bash
bundle exec rspec
bundle exec rubocop
bundle exec rake
bundle exec bin/console
bundle exec exe/ares [task]
```

## Architecture

```
lib/ares/
  cli.rb                    # Thor CLI entry point
  runtime.rb                # Top-level orchestration
  runtime/
    adapters/
      base_adapter.rb       # Adapter interface
      claude_adapter.rb     # Claude API adapter
      codex_adapter.rb      # Codex (GitHub Copilot) adapter
      cursor_adapter.rb     # Cursor adapter
      ollama_adapter.rb     # Ollama adapter
    planner/                # Task planning (breaks task → steps)
    router.rb               # Routes task type → model + adapter
    model_selector.rb       # Selects model from models.yml
    prompt_builder.rb       # Builds prompts for each adapter
    context_loader.rb       # Loads workspace/repo context
    engine_chain.rb         # Chains plan → execute → fix
    diagnostic_runner.rb    # Runs tests/lint, captures failures
    diagnostic_parser.rb    # Parses RSpec/RuboCop output
    fix_applicator.rb       # Applies JSON patches to files
    quota_manager.rb        # API quota tracking
    task_manager.rb         # Task lifecycle management
    task_logger.rb          # Structured task logging
    git_manager.rb          # Git operations (commit, diff)
    tui.rb                  # Terminal UI
config/
  models.yml                # Task type → engine + model mapping
  ollama.yml                # Ollama model configuration
  workspaces.yml            # Registered workspaces
```

## Task → Engine routing (from models.yml)

| Task type | Engine |
|---|---|
| architecture | claude (opus) |
| refactor | claude (sonnet) |
| bulk_patch | codex |
| test_generation | codex |
| summarization | ollama |
| interactive_edit | cursor |
| pr_automation | codex |

## Key rules

- No recursive agent loops — deterministic one-hop execution per task
- `router.rb` is the only place that decides which engine to use — never hardcode engine selection elsewhere
- Adapters are stateless — no shared state between calls
- Fix mode returns JSON patches (`{"explanation": "...", "patches": [...]}`) — never modify files directly from adapter output without going through `fix_applicator.rb`
- All model names come from `config/models.yml` — never hardcode model names in Ruby
