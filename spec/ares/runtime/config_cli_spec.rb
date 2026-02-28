# frozen_string_literal: true

RSpec.describe Ares::Runtime::ConfigCLI do
  describe '.run' do
    it 'loads and prints models and ollama config' do
      expect { described_class.run }.to output(/Models Configuration/).to_stdout
    end
  end
end
