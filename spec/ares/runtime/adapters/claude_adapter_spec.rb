# frozen_string_literal: true

RSpec.describe Ares::Runtime::ClaudeAdapter do
  describe '#call' do
    it 'includes fork_session in command when requested' do
      system('true') # Set $CHILD_STATUS.success? for check_auth
      allow_any_instance_of(Object).to receive(:system).and_return(true)
      allow(Open3).to receive(:capture2e).and_return(['output', double(success?: true, exitstatus: 0)])
      adapter = described_class.new
      adapter.call('prompt', 'sonnet', fork_session: true)
      expect(Open3).to have_received(:capture2e) do |*args|
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
