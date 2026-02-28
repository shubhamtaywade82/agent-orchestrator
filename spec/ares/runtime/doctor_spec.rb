# frozen_string_literal: true

RSpec.describe Ares::Runtime::Doctor do
  describe '.run' do
    it 'runs diagnostics and prints results' do
      expect { described_class.run }.to output(/Running Ares diagnostics/).to_stdout
    end
  end

  describe '.check_ollama' do
    it 'prints Ollama status' do
      expect { described_class.check_ollama }.to output(/Ollama:/).to_stdout
    end
  end

  describe '.check_claude' do
    it 'prints Claude CLI status' do
      expect { described_class.check_claude }.to output(/Claude CLI:/).to_stdout
    end
  end

  describe '.check_codex' do
    it 'prints Codex CLI status' do
      expect { described_class.check_codex }.to output(/Codex CLI:/).to_stdout
    end
  end

  describe '.check_cursor' do
    it 'prints Cursor CLI status' do
      expect { described_class.check_cursor }.to output(/Cursor CLI:/).to_stdout
    end
  end
end
