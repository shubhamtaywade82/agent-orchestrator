# 🛠️ Universal Self-Healing Guide

Ares 2.0 features a generalized "Self-Healing" loop that automates the repair of tests, linting violations, and syntax errors.

## 🌀 The Self-Healing Loop

When a verification command fails, Ares enters a 3-step repair cycle:

1. **Summarization**: Local Ollama parses the raw terminal output to identify the exact files and lines that failed.
2. **AI Escalation**: Ares reads the failing source code and sends it to the selected LLM (Claude or Ollama fallback) with a strict JSON patch schema.
3. **Verification**: After applying the generated fix, Ares automatically re-runs the original command to ensure the issue is resolved.

## 🧬 Supported Verifications

### 1. Test Self-Healing (RSpec)
Triggered by: `bin/ares "run tests"`
- Identifies failing specs and the corresponding implementation files.
- Generates precise code changes to satisfy test expectations.

### 2. Syntax Auto-Repair
Triggered by: `bin/ares "check syntax"`
- Uses `ruby -c` to find syntax errors (e.g., missing `end`, unexpected tokens).
- Fixes code structural errors before they block the rest of the pipeline.

### 3. AI-Powered Linting (RuboCop)
Triggered by: `bin/ares "lint project"`
- First attempts a standard `rubocop -A` (auto-correct).
- If offenses remain, Ares escalates to the AI to perform deep refactors (e.g., splitting a method that is too long).

## 🛡️ Safety Boundaries

To prevent "AI hallucinations" from corrupting the orchestrator:
- **Filesystem Locking**: The AI is strictly forbidden from modifying files in `lib/core/` and `lib/adapters/` unless they are the direct cause of the failure.
- **Grounding**: The AI is only shown the specific files that failed, preventing it from straying into unrelated code.
- **Refusal Policy**: If the AI determines a bug is in the engine itself, it is instructed to refuse the fix and provide an explanation instead.
