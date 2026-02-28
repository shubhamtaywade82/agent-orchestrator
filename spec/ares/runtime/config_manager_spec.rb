# frozen_string_literal: true

RSpec.describe Ares::Runtime::ConfigManager do
  describe '.load_file' do
    it 'returns empty hash when file does not exist' do
      expect(described_class.load_file('/nonexistent/path')).to eq({})
    end

    it 'returns empty hash when YAML is not a Hash' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'bad.yml')
        File.write(path, 'not a hash')
        expect(described_class.load_file(path)).to eq({})
      end
    end

    it 'returns symbolized hash when valid YAML exists' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'good.yml')
        File.write(path, "foo: bar\nbaz: 1")
        expect(described_class.load_file(path)).to eq(foo: 'bar', baz: 1)
      end
    end

    it 'returns empty hash when YAML raises' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'invalid.yml')
        File.write(path, "foo: \n  invalid: yaml: :")
        expect(described_class.load_file(path)).to eq({})
      end
    end
  end

  describe '.load_models' do
    it 'returns merged models config' do
      result = described_class.load_models
      expect(result).to be_a(Hash)
      expect(result.keys).to include(:refactor, :architecture)
    end
  end

  describe '.load_ollama' do
    it 'returns ollama config' do
      result = described_class.load_ollama
      expect(result).to be_a(Hash)
    end
  end

  describe '.task_types' do
    it 'returns keys from load_models' do
      result = described_class.task_types
      expect(result).to be_an(Array)
      expect(result).to include(:refactor)
    end
  end

  describe '.project_root' do
    it 'returns current dir when config/ares/models.yml not found' do
      allow(File).to receive(:exist?).and_return(false)
      allow(Dir).to receive(:pwd).and_return('/tmp/foo')
      expect(described_class.project_root).to eq('/tmp/foo')
    end

    it 'returns dir containing config/ares/models.yml' do
      original_pwd = Dir.pwd
      Dir.mktmpdir do |dir|
        config_dir = File.join(dir, 'config', 'ares')
        FileUtils.mkdir_p(config_dir)
        File.write(File.join(config_dir, 'models.yml'), '{}')
        Dir.chdir(dir) do
          expect(described_class.project_root).to eq(dir)
        end
      end
    ensure
      Dir.chdir(original_pwd)
    end
  end

  describe '.local_path' do
    it 'returns path under project_root config/ares' do
      allow(described_class).to receive(:project_root).and_return('/proj')
      expect(described_class.local_path('models.yml')).to eq('/proj/config/ares/models.yml')
    end
  end

  describe '.global_path' do
    it 'returns path under GLOBAL_DIR' do
      expect(described_class.global_path('models.yml')).to include('.ares', 'models.yml')
    end
  end

  describe '.gem_default_path' do
    it 'returns path under gem dir when spec found' do
      spec = instance_double(Gem::Specification, gem_dir: '/gem/dir')
      allow(Gem).to receive(:loaded_specs).and_return('ares-runtime' => spec)
      expect(described_class.gem_default_path('models.yml')).to eq('/gem/dir/config/models.yml')
    end

    it 'returns relative path when gem spec not found' do
      allow(Gem).to receive(:loaded_specs).and_return({})
      allow(Gem::Specification).to receive(:find_by_name).with('ares-runtime').and_return(nil)
      path = described_class.gem_default_path('models.yml')
      expect(path).to include('config', 'models.yml')
    end
  end

  describe '.save_config' do
    it 'writes config to file' do
      Dir.mktmpdir do |dir|
        target = File.join(dir, 'test.yml')
        allow(described_class).to receive(:local_path).and_return(File.join(dir, 'nonexistent', 'test.yml'))
        allow(described_class).to receive(:global_path).and_return(target)
        described_class.save_config('test.yml', { foo: 'bar' })
        expect(File.read(target)).to include('foo', 'bar')
      end
    end

    it 'handles nil config' do
      Dir.mktmpdir do |dir|
        target = File.join(dir, 'nil.yml')
        allow(described_class).to receive(:local_path).and_return(File.join(dir, 'x', 'nil.yml'))
        allow(described_class).to receive(:global_path).and_return(target)
        described_class.save_config('nil.yml', nil)
        expect(File.read(target)).to include('{}')
      end
    end
  end

  describe '.update_task_config' do
    it 'updates and saves task config' do
      Dir.mktmpdir do |dir|
        config_dir = File.join(dir, 'config', 'ares')
        FileUtils.mkdir_p(config_dir)
        models_path = File.join(config_dir, 'models.yml')
        File.write(models_path, "refactor:\n  engine: claude\n  model: sonnet\n")
        Dir.chdir(dir) do
          described_class.update_task_config(:refactor, :codex, 'default')
          data = YAML.load_file(models_path)
          expect(data['refactor']['engine'].to_s).to eq('codex')
        end
      end
    end
  end

  describe '.deep_merge' do
    it 'merges nested hashes' do
      a = { foo: { a: 1 } }
      b = { foo: { b: 2 } }
      expect(described_class.deep_merge(a, b)).to eq(foo: { a: 1, b: 2 })
    end

    it 'overwrites non-hash values' do
      a = { foo: 1 }
      b = { foo: 2 }
      expect(described_class.deep_merge(a, b)).to eq(foo: 2)
    end
  end

  describe '.symbolize_keys' do
    it 'converts string keys to symbols' do
      expect(described_class.symbolize_keys('a' => 1, 'b' => 2)).to eq(a: 1, b: 2)
    end

    it 'returns empty hash for non-hash input' do
      expect(described_class.symbolize_keys(nil)).to eq({})
    end

    it 'recursively symbolizes nested hashes' do
      input = { 'outer' => { 'inner' => 1 } }
      expect(described_class.symbolize_keys(input)).to eq(outer: { inner: 1 })
    end

    it 'keeps key when to_sym raises' do
      bad_key = Class.new { def to_sym; raise 'nope'; end }.new
      input = { bad_key => 1 }
      result = described_class.symbolize_keys(input)
      expect(result.keys.first).to eq(bad_key)
      expect(result.values.first).to eq(1)
    end
  end

  describe '.stringify_keys' do
    it 'converts symbol keys to strings' do
      expect(described_class.stringify_keys(a: 1, b: 2)).to eq('a' => 1, 'b' => 2)
    end

    it 'returns empty hash for nil input' do
      expect(described_class.stringify_keys(nil)).to eq({})
    end

    it 'recursively stringifies nested hashes' do
      input = { outer: { inner: 1 } }
      expect(described_class.stringify_keys(input)).to eq('outer' => { 'inner' => 1 })
    end
  end
end
