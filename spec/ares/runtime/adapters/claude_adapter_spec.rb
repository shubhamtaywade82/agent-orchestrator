# frozen_string_literal: true

RSpec.describe Ares::Runtime::ClaudeAdapter do
  def stub_popen2e
    stdin = double('stdin')
    allow(stdin).to receive(:write)
    allow(stdin).to receive(:close)
    outerr = double('outerr', read: 'output')
    wait_thr = double('wait_thr', value: double(success?: true, exitstatus: 0))
    allow(Open3).to receive(:popen2e).and_yield(stdin, outerr, wait_thr)
  end

  describe '#call' do
    it 'includes fork_session in command when requested' do
      system('true') # Set $CHILD_STATUS.success? for check_auth
      allow_any_instance_of(Object).to receive(:system).and_return(true)
      stub_popen2e
      allow_any_instance_of(Ares::Runtime::BaseAdapter).to receive(:run_command_in_fork) do |receiver, cmd, prompt|
        receiver.send(:run_command, cmd, prompt)
      end
      adapter = described_class.new
      adapter.call('prompt', 'sonnet', fork_session: true)
      expect(Open3).to have_received(:popen2e) do |*args|
        args.include?('--continue') && args.include?('--fork-session')
      end
    end

    it 'raises when not logged in' do
      system('false') # Set $CHILD_STATUS.success? to false
      allow_any_instance_of(Object).to receive(:system).and_return(false)
      expect { described_class.new.call('prompt') }.to raise_error(/Claude CLI not logged in/)
    end
  end
end
