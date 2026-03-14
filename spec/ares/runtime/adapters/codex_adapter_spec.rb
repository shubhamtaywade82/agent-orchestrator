# frozen_string_literal: true

RSpec.describe Ares::Runtime::CodexAdapter do
  before do
    stdin = double('stdin')
    allow(stdin).to receive(:write)
    allow(stdin).to receive(:close)
    outerr = double('outerr', read: 'output')
    wait_thr = double('wait_thr', value: double(success?: true, exitstatus: 0))
    allow(Open3).to receive(:popen2e).and_yield(stdin, outerr, wait_thr)
    allow_any_instance_of(Ares::Runtime::BaseAdapter).to receive(:run_command_in_fork) do |receiver, cmd, prompt|
      receiver.send(:run_command, cmd, prompt)
    end
  end

  describe '#call' do
    it 'builds codex exec command' do
      adapter = described_class.new
      adapter.call('prompt')
      expect(Open3).to have_received(:popen2e) do |*args|
        args.include?('codex') && args.include?('exec') && args.include?('--full-auto')
      end
    end
  end

  describe '#apply_cloud_task' do
    it 'runs codex apply' do
      allow(Ares::Runtime::TerminalRunner).to receive(:run).and_return(output: 'ok', exit_status: 0)
      described_class.new.apply_cloud_task('task-123')
      expect(Ares::Runtime::TerminalRunner).to have_received(:run).with(%w[codex apply task-123])
    end
  end
end
