# frozen_string_literal: true

require_relative 'lib/ares/runtime/version'

Gem::Specification.new do |s|
  s.name        = 'ares-runtime'
  s.version     = Ares::Runtime::VERSION
  s.summary     = 'Deterministic Multi-Agent Orchestrator'
  s.description = 'A production-grade control plane for routing tasks to Claude, Codex, and Cursor with local planning.'
  s.authors     = ['Antigravity']
  s.email       = ['shubhamtaywade82@gmail.com']
  s.files       = Dir.glob('lib/**/*.rb') +
                  Dir.glob('exe/*') +
                  Dir.glob('config/*.yml') +
                  ['README.md', 'LICENSE.txt', 'CHANGELOG.md']
  s.executables = ['ares']
  s.bindir      = 'exe'
  s.homepage    = 'https://github.com/shubhamtaywade82/agent-orchestrator'
  s.license     = 'MIT'
  s.require_paths = ['lib']

  s.add_dependency 'dotenv'
  s.add_dependency 'json'
  s.add_dependency 'ollama-client', '~> 1.0'
  s.add_dependency 'tty-box'
  s.add_dependency 'tty-command'
  s.add_dependency 'tty-cursor'
  s.add_dependency 'tty-prompt'
  s.add_dependency 'tty-screen'
  s.add_dependency 'tty-spinner'
  s.add_dependency 'tty-table'
  s.add_dependency 'yaml'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['homepage_uri'] = s.homepage
  s.metadata['source_code_uri'] = s.homepage
  s.metadata['changelog_uri'] = "#{s.homepage}/blob/main/CHANGELOG.md"

  s.required_ruby_version = '>= 2.7.0'
end
