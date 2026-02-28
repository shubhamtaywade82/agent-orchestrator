# frozen_string_literal: true

RSpec.describe Ares::Runtime::OllamaPlanner do
  describe '#plan' do
    context 'when unhealthy' do
      it 'returns safe_default_plan' do
        planner = described_class.new(healthy: false)
        result = planner.plan('fix bug')
        expect(result['task_type']).to eq('refactor')
        expect(result['risk_level']).to eq('medium')
        expect(result['confidence']).to eq(1.0)
        expect(result['slices']).to eq(['fix bug'])
        expect(result['explanation']).to include('Safe Mode')
      end
    end

    context 'when healthy' do
      it 'returns safe_default_plan when Ollama fails' do
        planner = described_class.new(healthy: true)
        fallback = { 'task_type' => 'refactor', 'risk_level' => 'medium', 'confidence' => 1.0,
                     'slices' => ['fix bug'], 'explanation' => 'Safe Mode Default' }
        allow(Ares::Runtime::OllamaClientFactory).to receive(:with_resilience).and_return(fallback)
        result = planner.plan('fix bug')
        expect(result['explanation']).to include('Safe Mode')
      end
    end
  end
end
