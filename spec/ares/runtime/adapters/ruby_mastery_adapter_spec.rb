# frozen_string_literal: true

RSpec.describe Ares::Runtime::RubyMasteryAdapter do
  describe '#call' do
    it 'prepends Ruby expert system prompt and delegates to Claude' do
      prompt_captured = nil
      allow_any_instance_of(Ares::Runtime::ClaudeAdapter).to receive(:call) do |_receiver, prompt, *rest|
        prompt_captured = prompt
        'output'
      end

      adapter = described_class.new
      adapter.call('review lib/foo.rb')

      expect(prompt_captured).to start_with(described_class::SYSTEM_PROMPT)
      expect(prompt_captured).to include('review lib/foo.rb')
    end

    it 'passes model and options through to Claude' do
      call_args = nil
      allow_any_instance_of(Ares::Runtime::ClaudeAdapter).to receive(:call) do |_receiver, *args|
        call_args = args
        'ok'
      end

      adapter = described_class.new
      adapter.call('task', 'sonnet', fork_session: true)

      expect(call_args[1]).to eq('sonnet')
      expect(call_args[2]).to include(fork_session: true)
    end
  end
end
