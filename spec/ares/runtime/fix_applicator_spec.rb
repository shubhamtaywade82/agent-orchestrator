# frozen_string_literal: true

RSpec.describe Ares::Runtime::FixApplicator do
  let(:spinner) { instance_double(TTY::Spinner, update: nil, run: nil) }
  let(:diagnostic_runner) { instance_double(Ares::Runtime::DiagnosticRunner, print_summary: nil) }
  let(:core) { instance_double(Ares::Runtime::CoreSubsystem, tiny_processor: nil) }

  before do
    allow(spinner).to receive(:run) { |&block| block&.call }
  end

  describe '#escalate' do
    context 'with syntax type' do
      it 'escalates once' do
        allow(Ares::Runtime::ModelSelector).to receive(:select).and_return(engine: :claude, model: 'sonnet')
        allow(Ares::Runtime::EngineChain).to receive(:build_fallback).and_return(
          chain: double(call_fix: '{"patches":[]}'),
          size: 1
        )
        allow(Ares::Runtime::TerminalRunner).to receive(:run).and_return(exit_status: 0)
        allow(Ares::Runtime::ContextLoader).to receive(:load).and_return('')
        applicator = described_class.new(core: core, spinner: spinner, diagnostic_runner: diagnostic_runner)
        result = applicator.escalate(
          type: :syntax,
          summary: { 'failed_items' => [], 'error_summary' => 'x', 'files' => [] },
          verify_command: 'echo'
        )
        expect(result).to be true
      end
    end

    context 'with syntax type and patches' do
      it 'applies patches when fix returns them' do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write('fix_me.rb', 'bad')
            allow(Ares::Runtime::ModelSelector).to receive(:select).and_return(engine: :claude, model: 'sonnet')
            chain = double('EngineChain')
            allow(chain).to receive(:call_fix).and_return({ 'patches' => [{ 'file' => 'fix_me.rb', 'content' => 'good' }] }.to_json)
            allow(Ares::Runtime::EngineChain).to receive(:build_fallback).and_return(chain: chain, size: 1)
            allow(Ares::Runtime::TerminalRunner).to receive(:run).and_return(exit_status: 0)
            allow(Ares::Runtime::ContextLoader).to receive(:load).and_return('')
            applicator = described_class.new(core: core, spinner: spinner, diagnostic_runner: diagnostic_runner)
            result = applicator.escalate(
              type: :syntax,
              summary: { 'failed_items' => ['x'], 'error_summary' => 'x', 'files' => [{ 'path' => 'fix_me.rb', 'line' => 1 }] },
              verify_command: 'echo'
            )
            expect(File.read('fix_me.rb')).to eq('good')
            expect(result).to be true
          end
        end
      end
    end
  end
end
