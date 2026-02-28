# frozen_string_literal: true

RSpec.describe Ares::Runtime::TerminalRunner do
  describe '.run' do
    it 'returns output and exit_status for successful command' do
      result = described_class.run('echo hello')
      expect(result[:output]).to include('hello')
      expect(result[:exit_status]).to eq(0)
    end

    it 'accepts array command' do
      result = described_class.run(%w[echo hello])
      expect(result[:output]).to include('hello')
      expect(result[:exit_status]).to eq(0)
    end

    it 'returns error hash when command fails' do
      result = described_class.run('exit 1')
      expect(result[:output]).not_to be_empty
      expect(result[:exit_status]).to eq(1)
    end

    it 'passes stdin_data when provided' do
      result = described_class.run('cat', stdin_data: 'input')
      expect(result[:output]).to eq('input')
      expect(result[:exit_status]).to eq(0)
    end
  end

  describe '.run_sandboxed' do
    it 'wraps command with codex sandbox' do
      allow(described_class).to receive(:run).and_return(output: 'ok', exit_status: 0)
      described_class.run_sandboxed('echo test')
      expect(described_class).to have_received(:run).with(array_including('codex', 'sandbox', 'echo test'))
    end
  end
end
