# frozen_string_literal: true

RSpec.describe Ares::Runtime::DiagnosticRunner do
  let(:spinner) { instance_double(TTY::Spinner, update: nil, run: nil) }
  let(:core) { instance_double(Ares::Runtime::CoreSubsystem, tiny_processor: tiny_processor) }
  let(:tiny_processor) { instance_double(Ares::Runtime::TinyTaskProcessor, summarize_output: { 'failed_items' => [], 'error_summary' => 'x', 'files' => [] }) }

  before do
    allow(spinner).to receive(:run) { |&block| block&.call }
  end

  describe '#run_tests' do
    it 'runs rspec and reports success when passing' do
      allow(Ares::Runtime::TerminalRunner).to receive(:run).and_return(output: '', exit_status: 0)
      runner = described_class.new(core: core, spinner: spinner)
      expect { runner.run_tests }.to output(/passed/).to_stdout
    end

    it 'prints summary and skips escalation on dry_run when failing' do
      allow(Ares::Runtime::TerminalRunner).to receive(:run).and_return(output: 'failure', exit_status: 1)
      allow(Ares::Runtime::DiagnosticParser).to receive(:parse).and_return(
        'failed_items' => ['x'], 'error_summary' => '1 failed', 'files' => []
      )
      table = instance_double(TTY::Table, render: 'table')
      allow(table).to receive(:<<).and_return(table)
      allow(TTY::Table).to receive(:new).and_return(table)
      runner = described_class.new(core: core, spinner: spinner)
      expect { runner.run_tests(dry_run: true) }.to output(/Dry run/).to_stdout
    end

    it 'uses LLM fallback when parse returns empty files' do
      allow(Ares::Runtime::TerminalRunner).to receive(:run).and_return(output: 'raw output', exit_status: 1)
      allow(Ares::Runtime::DiagnosticParser).to receive(:parse).and_return(
        'failed_items' => [], 'error_summary' => 'x', 'files' => []
      )
      allow(tiny_processor).to receive(:summarize_output).and_return(
        'failed_items' => ['x'], 'error_summary' => 'LLM summary', 'files' => []
      )
      table = instance_double(TTY::Table, render: 'table')
      allow(table).to receive(:<<).and_return(table)
      allow(TTY::Table).to receive(:new).and_return(table)
      allow(Ares::Runtime::FixApplicator).to receive(:new).and_return(double(escalate: true))
      runner = described_class.new(core: core, spinner: spinner)
      runner.run_tests
      expect(tiny_processor).to have_received(:summarize_output).with('raw output', type: :test)
    end
  end

  describe '#print_summary' do
    it 'prints table with failed items' do
      table = instance_double(TTY::Table, render: 'table')
      allow(table).to receive(:<<).and_return(table)
      allow(TTY::Table).to receive(:new).and_return(table)
      runner = described_class.new(core: core, spinner: spinner)
      expect { runner.print_summary({ 'failed_items' => ['a'], 'error_summary' => 'x' }, :lint) }.to output(/Failed Items|table/).to_stdout
    end
  end
end
