# frozen_string_literal: true

RSpec.describe Ares::Runtime::TinyTaskProcessor do
  describe '#summarize_output' do
    context 'when unhealthy (Ollama unavailable)' do
      it 'returns safe fallback without calling Ollama' do
        processor = described_class.new(healthy: false)
        result = processor.summarize_output('some output', type: :lint)
        expect(result['error_summary']).to include('Safe Mode')
        expect(result['failed_items']).to eq([])
        expect(result['files']).to eq([])
      end
    end

    context 'when healthy' do
      it 'returns LLM summary when Ollama succeeds' do
        processor = described_class.new(healthy: true)
        allow(processor.instance_variable_get(:@client)).to receive(:generate).and_return(
          'failed_items' => ['a.rb:1'], 'error_summary' => '1 offense', 'files' => [{ 'path' => 'a.rb', 'line' => 1 }]
        )
        allow(Ares::Runtime::OllamaClientFactory).to receive(:with_resilience).and_yield
        result = processor.summarize_output("lib/foo.rb:10:5: C: Line too long\n", type: :lint)
        expect(result['failed_items']).to eq(['a.rb:1'])
      end

      it 'truncates output over MAX_SUMMARY_INPUT' do
        processor = described_class.new(healthy: true)
        long_output = 'x' * 10_000
        allow(processor.instance_variable_get(:@client)).to receive(:generate).and_return(
          'failed_items' => [], 'error_summary' => 'ok', 'files' => []
        )
        allow(Ares::Runtime::OllamaClientFactory).to receive(:with_resilience).and_yield
        result = processor.summarize_output(long_output, type: :syntax)
        expect(result['failed_items']).to eq([])
      end
    end
  end

  describe '#summarize_diff' do
    context 'when unhealthy' do
      it 'returns safe fallback' do
        processor = described_class.new(healthy: false)
        result = processor.summarize_diff('diff content')
        expect(result['change_summary']).to include('Safe Mode')
        expect(result['modified_files']).to eq([])
        expect(result['risk_level']).to eq('medium')
      end
    end

    context 'when healthy' do
      it 'returns LLM diff summary' do
        processor = described_class.new(healthy: true)
        allow(processor.instance_variable_get(:@client)).to receive(:generate).and_return(
          'modified_files' => ['a.rb'], 'change_summary' => 'Changed', 'risk_level' => 'low'
        )
        allow(Ares::Runtime::OllamaClientFactory).to receive(:with_resilience).and_yield
        result = processor.summarize_diff('diff')
        expect(result['modified_files']).to eq(['a.rb'])
      end
    end
  end
end
