# 🧠 Ares 2.0: Agent Orchestrator

A production-grade, deterministic multi-agent orchestrator CLI. Ares routes tasks to the best localized executor (Claude, Codex, or Cursor) based on a strategic planning phase powered by Ollama.

## 🏗️ Architecture

- **Planning Layer**: Uses local Ollama model to classify tasks into types (architecture, refactor, bulk_patch, etc.) and assign risk/confidence scores.
- **Routing Layer**: Deterministic rules in `config/models.yml` allocate tasks to engines.
- **Context Injection**: Automatically loads `AGENTS.md` and `.skills/` from the active workspace.
- **Traceability**: Every task receives a UUID and is logged in `logs/UUID.json`.
- **Safety**: Built-in quota tracking and confidence-based escalation to Claude Opus for high-risk work.

## 🚀 Usage

Install dependencies:
```bash
bundle install
```

Run a task:
```bash
bin/ares "Task description"
```

### Flags
- `-d, --dry-run`: Plan and select model without execution.
- `-g, --git`: Auto-branch before execution and auto-commit results.

## 🎯 Model Routing Rules

Routed via `config/models.yml`:
- **Architecture**: Claude Opus (High Reasoning)
- **Refactor**: Claude Sonnet (Primary Executor)
- **Bulk Patch / Test Gen**: Codex (High Speed)
- **Interactive Edit**: Cursor Agent (Human-in-the-loop)
- **Summarization**: Claude Haiku (Low Cost)

## 🔐 Safety Rules

1. **Deterministic One-Hop**: No recursive agent loops.
2. **Quota Aware**: Claude usage is tracked daily.
3. **Low Confidence Escalation**: Automatically moves to Opus if the planner is unsure.
4. **Workspace Isolation**: Execution is pinned to the current directory's context.
