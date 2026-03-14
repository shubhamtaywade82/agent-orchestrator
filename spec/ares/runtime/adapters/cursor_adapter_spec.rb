# frozen_string_literal: true

RSpec.describe Ares::Runtime::CursorAdapter do
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
    it 'prepends agent instructions to prompt' do
      adapter = described_class.new
      adapter.call('do X')
      expect(Open3).to have_received(:popen2e) do |*args|
        args.any? { |a| a.to_s.include?('autonomous') }
      end
    end

    it 'does not pipe prompt to stdin' do
      adapter = described_class.new
      expect(adapter.send(:pipes_prompt_to_stdin?)).to be false
    end
  end
end
