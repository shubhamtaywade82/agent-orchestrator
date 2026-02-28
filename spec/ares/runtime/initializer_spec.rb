# frozen_string_literal: true

RSpec.describe Ares::Runtime::Initializer do
  describe '.run' do
    it 'skips when config dir already exists' do
      Dir.mktmpdir do |dir|
        config_dir = File.join(dir, 'config', 'ares')
        FileUtils.mkdir_p(config_dir)
        Dir.chdir(dir) do
          expect { described_class.run }.to output(/already initialized/).to_stdout
        end
      end
    end

    it 'creates config dir and copies defaults when new' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect { described_class.run }.to output(/Initialized Ares/).to_stdout
          expect(Dir.exist?(File.join(dir, 'config', 'ares'))).to be true
        end
      end
    end
  end
end
