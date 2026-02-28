# frozen_string_literal: true

RSpec.describe Ares::Runtime::TaskLogger do
  let(:logger) { described_class.new }

  describe '#initialize' do
    it 'generates task_id' do
      expect(logger.task_id).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe '#log_task' do
    it 'writes task data to log file' do
      Dir.mktmpdir do |dir|
        allow(Ares::Runtime::ConfigManager).to receive(:project_root).and_return(dir)
        logger = described_class.new
        logger.log_task('fix bug', 'plan-x', { engine: :claude })
        log_file = File.join(dir, 'logs', "#{logger.task_id}.json")
        expect(File.exist?(log_file)).to be true
        data = JSON.parse(File.read(log_file))
        expect(data['task']).to eq('fix bug')
        expect(data['plan']).to eq('plan-x')
      end
    end
  end

  describe '#log_result' do
    it 'appends result when log file exists' do
      Dir.mktmpdir do |dir|
        allow(Ares::Runtime::ConfigManager).to receive(:project_root).and_return(dir)
        logger = described_class.new
        logger.log_task('task', {}, {})
        logger.log_result('output')
        data = JSON.parse(File.read(File.join(dir, 'logs', "#{logger.task_id}.json")))
        expect(data['result']).to eq('output')
        expect(data['completed_at']).not_to be_empty
      end
    end

    it 'does nothing when log file does not exist' do
      logger = described_class.new
      expect { logger.log_result('output') }.not_to raise_error
    end
  end
end
