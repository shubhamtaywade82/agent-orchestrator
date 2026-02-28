# frozen_string_literal: true

RSpec.describe Ares::Runtime::LogsCLI do
  describe '.run' do
    it 'prints message when no logs dir exists' do
      allow(Ares::Runtime::ConfigManager).to receive(:project_root).and_return('/nonexistent')
      expect { described_class.run }.to output(/No logs found|No JSON logs/).to_stdout
    end

    it 'prints logs when they exist' do
      Dir.mktmpdir do |dir|
        log_dir = File.join(dir, 'logs')
        FileUtils.mkdir_p(log_dir)
        File.write(File.join(log_dir, 'task-1.json'), {
          'timestamp' => '2024-01-01',
          'task' => 'fix',
          'selection' => { 'engine' => 'claude' },
          'result' => 'output'
        }.to_json)
        allow(Ares::Runtime::ConfigManager).to receive(:project_root).and_return(dir)
        expect { described_class.run }.to output(/Task: task-1/).to_stdout
      end
    end
  end
end
