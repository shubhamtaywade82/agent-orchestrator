# frozen_string_literal: true

RSpec.describe Ares::Runtime::Router do
  describe '#initialize' do
    it 'creates Router with core subsystem' do
      expect(described_class.new).to be_a(described_class)
    end
  end

  describe '#run' do
    let(:router) { described_class.new }

    before do
      allow(router).to receive(:check_quota!)
      allow(router).to receive(:puts)
      allow(router).to receive(:match_shortcut_task).and_return(nil)
      allow(router).to receive(:plan_task).and_return('task_type' => 'refactor', 'confidence' => 0.9)
      allow(router).to receive(:select_model_for_plan).and_return(engine: :claude, model: 'sonnet')
      allow(router).to receive(:handle_low_confidence).and_return(engine: :claude, model: 'sonnet')
      allow(router).to receive(:execute_engine_task)
      allow(TTY::Spinner).to receive(:new).and_return(instance_double(TTY::Spinner, update: nil, run: nil))
      allow(Ares::Runtime::DiagnosticRunner).to receive(:new).and_return(instance_double(Ares::Runtime::DiagnosticRunner))
    end

    it 'executes engine task for non-shortcut task' do
      router.run('fix the bug')
      expect(router).to have_received(:execute_engine_task)
    end

    it 'returns shortcut result when task matches pattern' do
      allow(router).to receive(:match_shortcut_task).and_return(true)
      result = router.run('test')
      expect(result).to be true
      expect(router).not_to have_received(:execute_engine_task)
    end
  end

  describe 'match_shortcut_task' do
    it 'returns nil for non-matching task' do
      router = described_class.new
      result = router.send(:match_shortcut_task, 'random task xyz', {})
      expect(result).to be_nil
    end

    it 'invokes run_test_diagnostic for test task' do
      router = described_class.new
      diagnostic = instance_double(Ares::Runtime::DiagnosticRunner, run_tests: true)
      router.instance_variable_set(:@diagnostic, diagnostic)
      result = router.send(:match_shortcut_task, 'test', {})
      expect(diagnostic).to have_received(:run_tests)
      expect(result).to be true
    end
  end
end
