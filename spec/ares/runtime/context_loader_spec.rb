# frozen_string_literal: true

RSpec.describe Ares::Runtime::ContextLoader do
  describe '.load' do
    it 'returns workspace root in output' do
      allow(Ares::Runtime::ConfigManager).to receive(:load_merged).with('workspaces.yml').and_return(workspaces: [])
      result = described_class.load
      expect(result).to start_with('Workspace Root:')
    end

    it 'includes skills from .skills/SKILL.md when present' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'AGENTS.md'), '# Agents')
        skills_dir = File.join(dir, '.skills', 'foo')
        FileUtils.mkdir_p(skills_dir)
        File.write(File.join(skills_dir, 'SKILL.md'), 'Skill content')
        allow(Ares::Runtime::ConfigManager).to receive(:load_merged).and_return(workspaces: [])
        Dir.chdir(dir) do
          result = described_class.load
          expect(result).to include('Skill content')
        end
      end
    end
  end

  describe '.find_workspace_root' do
    it 'returns path when AGENTS.md exists in directory' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'AGENTS.md'), '# Agents')
        allow(Ares::Runtime::ConfigManager).to receive(:load_merged).and_return(workspaces: [])
        expect(described_class.find_workspace_root(dir)).to eq(dir)
      end
    end

    it 'returns registered workspace when path starts with it' do
      allow(Ares::Runtime::ConfigManager).to receive(:load_merged).and_return(
        workspaces: ['/registered/workspace']
      )
      result = described_class.find_workspace_root('/registered/workspace/subdir')
      expect(result).to eq('/registered/workspace')
    end
  end
end
