# frozen_string_literal: true

RSpec.describe Ares::Runtime::DiagnosticParser do
  describe '.strip_ansi' do
    it 'removes ANSI escape sequences from text' do
      expect(described_class.strip_ansi("\e[31mred\e[0m")).to eq('red')
    end

    it 'returns string representation for non-strings' do
      expect(described_class.strip_ansi(nil)).to eq('')
    end
  end

  describe '.build_error_summary' do
    it 'returns no-issues message when failed_items is empty' do
      expect(described_class.build_error_summary([], 'RuboCop')).to eq('No RuboCop issues found.')
    end

    it 'returns count message when failed_items has entries' do
      items = ['file.rb:1: offense']
      expect(described_class.build_error_summary(items, 'RuboCop')).to eq('There are 1 failed rubocop item(s).')
    end
  end

  describe '.remove_duplicates' do
    it 'deduplicates files by path and line' do
      files = [
        { 'path' => 'a.rb', 'line' => 1 },
        { 'path' => 'a.rb', 'line' => 1 },
        { 'path' => 'a.rb', 'line' => 2 }
      ]
      expect(described_class.remove_duplicates(files)).to eq([
        { 'path' => 'a.rb', 'line' => 1 },
        { 'path' => 'a.rb', 'line' => 2 }
      ])
    end
  end

  describe '.fallback_parse' do
    it 'returns fallback structure for empty output' do
      result = described_class.fallback_parse('', :lint)
      expect(result['failed_items']).to eq([''])
      expect(result['error_summary']).to eq('Parsed lint output via fallback.')
      expect(result['files']).to eq([])
    end

    it 'truncates long output to 50 lines' do
      long_output = (1..60).map { |i| "line #{i}" }.join("\n")
      result = described_class.fallback_parse(long_output, :lint)
      expect(result['failed_items'].first.lines.size).to eq(50)
    end
  end

  describe '.parse' do
    it 'returns fallback for nil output' do
      result = described_class.parse(nil, type: :lint)
      expect(result['failed_items']).not_to be_nil
      expect(result['error_summary']).to include('fallback')
    end

    it 'returns fallback for blank output' do
      result = described_class.parse('   ', type: :lint)
      expect(result).to include('failed_items', 'error_summary', 'files')
    end

    context 'with RuboCop JSON' do
      let(:rubocop_json) do
        {
          'files' => [
            {
              'path' => 'lib/foo.rb',
              'offenses' => [
                { 'message' => 'Line too long', 'location' => { 'line' => 10 } }
              ]
            }
          ]
        }.to_json
      end

      it 'parses RuboCop JSON into unified structure' do
        result = described_class.parse(rubocop_json, type: :lint)
        expect(result['failed_items']).to include(match(/foo\.rb:10/))
        expect(result['error_summary']).to match(/1 failed/)
        expect(result['files']).to include('path' => 'lib/foo.rb', 'line' => 10)
      end

      it 'uses start_line when line is missing' do
        json = {
          'files' => [
            {
              'path' => 'lib/bar.rb',
              'offenses' => [
                { 'message' => 'Offense', 'location' => { 'start_line' => 5 } }
              ]
            }
          ]
        }.to_json
        result = described_class.parse(json, type: :lint)
        expect(result['failed_items']).to include(match(/bar\.rb:5/))
      end
    end

    context 'with RSpec JSON' do
      let(:rspec_json) do
        {
          'examples' => [
            {
              'status' => 'failed',
              'file_path' => './spec/foo_spec.rb',
              'line_number' => 42,
              'exception' => { 'message' => 'expected 1, got 2' }
            }
          ]
        }.to_json
      end

      it 'parses RSpec JSON into unified structure' do
        result = described_class.parse(rspec_json, type: :spec)
        expect(result['failed_items']).to include(match(/foo_spec\.rb:42/))
        expect(result['error_summary']).to match(/1 failed/)
        expect(result['files']).to include('path' => 'spec/foo_spec.rb', 'line' => 42)
      end
    end

    context 'with syntax error output' do
      let(:syntax_output) { "lib/bar.rb:5: syntax error, unexpected end" }

      it 'parses syntax output into unified structure' do
        result = described_class.parse(syntax_output, type: :syntax)
        expect(result['failed_items']).to include(match(/bar\.rb:5/))
        expect(result['failed_items']).to include(match(/syntax error/))
      end
    end

    context 'with invalid RuboCop JSON (falls back to text parse)' do
      let(:rubocop_text) { "lib/foo.rb:10:5: C: Line is too long\n" }

      it 'parses RuboCop text format' do
        result = described_class.parse(rubocop_text, type: :lint)
        expect(result['failed_items']).to include(match(/foo\.rb:10/))
        expect(result['files']).to include('path' => 'lib/foo.rb', 'line' => 10)
      end
    end

    context 'with invalid RSpec JSON (falls back to text parse)' do
      let(:rspec_text) { "# ./spec/foo_spec.rb:42:in `block'" }

      it 'parses RSpec text format' do
        result = described_class.parse(rspec_text, type: :spec)
        expect(result['failed_items']).to include(match(/foo_spec\.rb:42/))
        expect(result['files']).to include('path' => 'spec/foo_spec.rb', 'line' => 42)
      end
    end
  end
end
