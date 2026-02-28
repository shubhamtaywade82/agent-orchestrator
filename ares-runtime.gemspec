Gem::Specification.new do |s|
  s.name        = "ares-runtime"
  s.version     = "2.0.0"
  s.summary     = "Deterministic Multi-Agent Orchestrator"
  s.description = "A production-grade control plane for routing tasks to Claude, Codex, and Cursor with local planning."
  s.authors     = ["Antigravity"]
  s.email       = ["antigravity@example.com"]
  s.files       = Dir.glob("{bin,lib,config}/**/*") + ["README.md", "Gemfile"]
  s.executables = ["ares"]
  s.homepage    = "https://github.com/example/agent-orchestrator"
  s.license     = "MIT"

  s.add_dependency "ollama-client", "~> 1.0"
  s.add_dependency "json"
  s.add_dependency "yaml"
end
