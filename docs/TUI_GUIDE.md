# 📟 Ares TUI Guide

The Ares Terminal User Interface (TUI) provides a professional dashboard for managing your AI orchestration workflow.

## 🚀 Launching the TUI

To enter the interactive mode, use the `--tui` flag:
```bash
bin/ares --tui
```

## 📊 Dashboard Overview

The dashboard is divided into three main sections:
1. **Quotas & Stats**: Real-time tracking of Claude usage and total tasks completed.
2. **Action Menu**: Navigate through the core capabilities of Ares.
3. **Task History**: A scrollable log of your most recent orchestration tasks.

## 🕹️ Interactive Actions

- **[T] Task**: Submit a new natural language task directly from the CLI.
- **[R] RSpec**: Run the test suite with automated self-healing.
- **[L] Lint**: Run RuboCop with AI-powered repair for complex violations.
- **[S] Syntax**: Perform a project-wide Ruby syntax check with auto-fix.
- **[C] Config**: Dynamically configure model routing and Ollama settings.
- **[Q] Quit**: Safely exit the orchestrator.

## ⚙️ In-App Configuration

The `[C] Config` menu allows you to:
- **Allocate Models**: Choose which engine (Claude, Codex, Cursor) handles specific tasks (Architecture, Refactor, etc.).
- **Ollama Settings**: Adjust your local server's `base_url`, `timeout`, and `num_ctx` without editing YAML files manually.
- **Model Discovery**: Ares automatically fetches available models from your local Ollama server for easy selection.

---
*Tip: Use the arrow keys and Enter to navigate menus. Most sub-menus include a 'Back' option to return to the dashboard.*
