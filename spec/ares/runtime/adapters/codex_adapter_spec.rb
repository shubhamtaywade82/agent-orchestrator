# frozen_string_literal: true

RSpec.describe Ares::Runtime::CodexAdapter do
  before do
    allow(Open3).to receive(:capture2e).and_return(['output', double(success?: true, exitstatus: 0)])
  end

  describe '#call' do
    it 'builds codex exec command' do
      adapter = described_class.new
      adapter.call('prompt')
      expect(Open3).to have_received(:capture2e) do |*args|
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
