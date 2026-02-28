# frozen_string_literal: true

RSpec.describe Ares::Runtime::ModelSelector do
  before do
    allow(Ares::Runtime::ConfigManager).to receive(:load_models).and_return(
      refactor: { engine: :claude, model: 'sonnet' },
      summarization: { engine: :ollama, model: 'default' }
    )
  end

  describe '.select' do
    it 'returns claude engine for refactor task type' do
      plan = { 'task_type' => 'refactor', 'confidence' => 0.9 }
      result = described_class.select(plan)
      expect(result[:engine]).to eq(:claude)
      expect(result[:model]).to eq('sonnet')
    end

    it 'escalates to claude opus when confidence is low' do
      plan = { 'task_type' => 'refactor', 'confidence' => 0.5 }
      result = described_class.select(plan)
      expect(result[:engine]).to eq(:claude)
      expect(result[:model]).to eq('opus')
    end

    it 'escalates to claude opus when risk_level is high' do
      plan = { 'task_type' => 'refactor', 'confidence' => 0.9, 'risk_level' => 'high' }
      result = described_class.select(plan)
      expect(result[:engine]).to eq(:claude)
      expect(result[:model]).to eq('opus')
    end

    it 'falls back to refactor config when task_type is unknown' do
      plan = { 'task_type' => 'unknown', 'confidence' => 0.9 }
      result = described_class.select(plan)
      expect(result[:engine]).to eq(:claude)
      expect(result[:model]).to eq('sonnet')
    end

    it 'restricts ollama from code-modifying tasks' do
      allow(Ares::Runtime::ConfigManager).to receive(:load_models).and_return(
        refactor: { engine: :ollama, model: 'default' }
      )
      plan = { 'task_type' => 'refactor', 'confidence' => 0.9 }
      result = described_class.select(plan)
      expect(result[:engine]).to eq(:claude)
      expect(result[:model]).to eq('sonnet')
    end
  end
end
