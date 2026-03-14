# frozen_string_literal: true

RSpec.describe Ares::Runtime::BaseAdapter do
  let(:adapter) { Ares::Runtime::CodexAdapter.new }

  def stub_popen2e
    stdin = double('stdin')
    allow(stdin).to receive(:write)
    allow(stdin).to receive(:close)
    outerr = double('outerr', read: 'output')
    wait_thr = double('wait_thr', value: double(success?: true, exitstatus: 0))
    allow(Open3).to receive(:popen2e).and_yield(stdin, outerr, wait_thr)
  end

  before do
    stub_popen2e
    allow_any_instance_of(Ares::Runtime::BaseAdapter).to receive(:run_command_in_fork) do |receiver, cmd, prompt|
      receiver.send(:run_command, cmd, prompt)
    end
  end

  describe '#call' do
    it 'returns output on success' do
      expect(adapter.call('prompt', 'sonnet')).to eq('output')
    end
  end

  describe '#adapter_name' do
    it 'returns adapter name without Adapter suffix' do
      expect(adapter.send(:adapter_name)).to eq('Codex')
    end
  end
end
