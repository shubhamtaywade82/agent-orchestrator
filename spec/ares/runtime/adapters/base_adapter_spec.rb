# frozen_string_literal: true

RSpec.describe Ares::Runtime::BaseAdapter do
  let(:adapter) { Ares::Runtime::CodexAdapter.new }

  before do
    allow(Open3).to receive(:capture2e).and_return(['output', double(success?: true, exitstatus: 0)])
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
