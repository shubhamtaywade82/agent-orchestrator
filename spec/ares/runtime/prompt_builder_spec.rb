# frozen_string_literal: true

RSpec.describe Ares::Runtime::PromptBuilder do
  describe '#add_context' do
    it 'appends non-empty context' do
      result = described_class.new.add_context('Some context')
      expect(result.build).to include('Some context')
    end

    it 'skips empty context' do
      result = described_class.new.add_context('   ')
      expect(result.build).to eq('')
    end
  end

  describe '#add_task' do
    it 'appends task section with TASK prefix' do
      result = described_class.new.add_task('Fix the bug')
      expect(result.build).to include('TASK:', 'Fix the bug')
    end
  end

  describe '#add_diagnostic' do
    it 'appends diagnostic summary with type and items' do
      result = described_class.new
        .add_diagnostic(:lint, ['file.rb:1: offense'], '1 offense')
      expect(result.build).to include('DIAGNOSTIC SUMMARY', 'LINT', 'file.rb:1: offense', '1 offense')
    end
  end

  describe '#add_files' do
    it 'returns self when files is nil' do
      result = described_class.new.add_files(nil)
      expect(result.build).to eq('')
    end

    it 'returns self when files is empty' do
      result = described_class.new.add_files([])
      expect(result.build).to eq('')
    end

    it 'includes file content when file exists' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write('foo.rb', 'puts 1')
          result = described_class.new.add_files([{ 'path' => 'foo.rb', 'line' => 1 }])
          expect(result.build).to include('FAILING FILE CONTENTS', 'foo.rb', 'puts 1')
        end
      end
    end

    it 'skips non-existent files' do
      result = described_class.new.add_files([{ 'path' => 'nonexistent.rb', 'line' => 1 }])
      expect(result.build).to eq('')
    end
  end

  describe '#add_instruction' do
    it 'appends non-empty instruction' do
      result = described_class.new.add_instruction('Do X')
      expect(result.build).to eq('Do X')
    end

    it 'skips empty instruction' do
      result = described_class.new.add_instruction('   ')
      expect(result.build).to eq('')
    end
  end

  describe '#build' do
    it 'joins sections with double newlines' do
      result = described_class.new
        .add_task('Task A')
        .add_instruction('Instruction B')
        .build
      expect(result).to eq("TASK:\nTask A\n\nInstruction B")
    end
  end
end
