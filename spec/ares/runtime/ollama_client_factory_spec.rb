# frozen_string_literal: true

RSpec.describe Ares::Runtime::OllamaClientFactory do
  describe '.build' do
    it 'returns Ollama client' do
      client = described_class.build(timeout_seconds: 5)
      expect(client).to be_a(Ollama::Client)
    end
  end

  describe '.health_check?' do
    it 'returns boolean' do
      expect([true, false]).to include(described_class.health_check?)
    end
  end

  describe '.with_resilience' do
    it 'returns block result when successful' do
      result = described_class.with_resilience(fallback_value: 'fallback') { 'success' }
      expect(result).to eq('success')
    end

    it 'returns fallback when block raises' do
      result = described_class.with_resilience(fallback_value: 'fallback') { raise 'error' }
      expect(result).to eq('fallback')
    end
  end
end
