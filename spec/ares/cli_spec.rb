# frozen_string_literal: true

RSpec.describe Ares::CLI do
  describe '.init' do
    it 'skips when config dir exists' do
      Dir.mktmpdir do |dir|
        config_dir = File.join(dir, 'config', 'ares')
        FileUtils.mkdir_p(config_dir)
        Dir.chdir(dir) do
          expect { described_class.init }.to output(/already exists/).to_stdout
        end
      end
    end

    it 'creates config and copies defaults when new' do
      project_root = File.expand_path('../..', __dir__)
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          allow(Ares::Runtime::ConfigManager).to receive(:project_root).and_return(dir)
          gem_spec = instance_double(Gem::Specification, gem_dir: project_root)
          allow(Gem::Specification).to receive(:find_by_name).with('agent-orchestrator').and_return(gem_spec)
          expect { described_class.init }.to output(/initialized/).to_stdout
          expect(Dir.exist?(File.join(dir, 'config', 'ares'))).to be true
          expect(File.exist?(File.join(dir, 'config', 'ares', 'models.yml'))).to be true
        end
      end
    end
  end
end
