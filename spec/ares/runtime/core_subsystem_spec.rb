# frozen_string_literal: true

RSpec.describe Ares::Runtime::CoreSubsystem do
  describe '#initialize' do
    it 'creates logger, planner, and tiny_processor' do
      subsystem = described_class.new
      expect(subsystem.logger).to be_a(Ares::Runtime::TaskLogger)
      expect(subsystem.planner).to be_a(Ares::Runtime::OllamaPlanner)
      expect(subsystem.tiny_processor).to be_a(Ares::Runtime::TinyTaskProcessor)
    end
  end
end
