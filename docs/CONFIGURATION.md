# ⚙️ Configuration Guide

Ares is highly configurable via YAML files or through the interactive TUI.

## 📂 Configuration Files

All settings are stored in the `config/` directory:

### 1. `config/models.yml`
Controls task-to-engine routing.
```yaml
architecture:
  engine: claude
  model: opus
refactor:
  engine: claude
  model: sonnet
test_generation:
  engine: codex
```

### 2. `config/ollama.yml`
Global settings for the local Ollama server.
- `base_url`: Endpoint of your Ollama instance.
- `timeout`: Maximum time (in seconds) to wait for a response.
- `num_ctx`: Context window size (higher is better for large files).
- `retries`: Number of failed attempts before giving up.

### 3. `config/workspaces.yml`
(Optional) Register explicit root directories for agent discovery.

## 📟 Interactive Configuration

The preferred way to update settings is via the **TUI Configuration Mode** (`[C] Config`). This mode provides:
- Live validation of settings.
- Dynamic discovery of local Ollama models.
- Immediate persistence of changes.

## 🔋 Model Allocation Strategy

- **Claude Opus**: Reserved for "Architecture" tasks due to high reasoning depth.
- **Claude Sonnet**: The default workhorse for "Refactor" and general coding.
- **Codex**: Ideal for bulk tasks like unit test generation.
- **Local Ollama**: Used as the primary summarizer and a reliable fallback for all other engines.
