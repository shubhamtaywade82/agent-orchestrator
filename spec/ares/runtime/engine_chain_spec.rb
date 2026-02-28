# frozen_string_literal: true

RSpec.describe Ares::Runtime::EngineChain do
  describe '.build_fallback' do
    it 'returns chain and size for given engine' do
      result = described_class.build_fallback(:claude)
      expect(result[:chain]).to be_a(described_class)
      expect(result[:size]).to eq(4)
    end

    it 'puts initial engine first in fallback order' do
      result = described_class.build_fallback(:codex)
      expect(result[:chain].engine_name).to eq('codex')
    end
  end

  describe '.build' do
    it 'returns nil for empty engine list' do
      expect(described_class.build([])).to be_nil
    end

    it 'builds chain with single engine' do
      chain = described_class.build(%w[claude])
      expect(chain.engine_name).to eq('claude')
      expect(chain.next_handler).to be_nil
    end

    it 'links multiple engines' do
      chain = described_class.build(%w[claude codex])
      expect(chain.engine_name).to eq('claude')
      expect(chain.next_handler.engine_name).to eq('codex')
      expect(chain.next_handler.next_handler).to be_nil
    end
  end

  describe 'get_adapter' do
    it 'raises when unknown engine' do
      expect { described_class.build(%w[unknown]) }.to raise_error(/Unknown engine/)
    end
  end
end
