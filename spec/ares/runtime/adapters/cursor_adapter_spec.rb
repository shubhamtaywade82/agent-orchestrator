# frozen_string_literal: true

RSpec.describe Ares::Runtime::CursorAdapter do
  before do
    allow(Open3).to receive(:capture2e).and_return(['output', double(success?: true, exitstatus: 0)])
  end

  describe '#call' do
    it 'prepends agent instructions to prompt' do
      adapter = described_class.new
      adapter.call('do X')
      expect(Open3).to have_received(:capture2e) do |*args|
        args.any? { |a| a.to_s.include?('autonomous executor') }
      end
    end

    it 'does not pipe prompt to stdin' do
      adapter = described_class.new
      expect(adapter.send(:pipes_prompt_to_stdin?)).to be false
    end
  end
end
