# frozen_string_literal: true

RSpec.describe Ares::Runtime::GitManager do
  before do
    allow(described_class).to receive(:`).and_call_original
    allow(described_class).to receive(:`).with(/git rev-parse/).and_return("main\n")
    allow(described_class).to receive(:`).with(/git checkout/).and_return('')
    allow(described_class).to receive(:`).with('git add .').and_return('')
    allow(described_class).to receive(:`).with(/git commit/).and_return('')
  end

  describe '.create_branch' do
    it 'builds branch name with task_id and slug from description' do
      described_class.create_branch('abc-123', 'Fix the bug')
      expect(described_class).to have_received(:`).with(/task-abc-123-fix-the-bug/)
    end

    it 'builds branch name with only task_id when no description' do
      described_class.create_branch('abc-123')
      expect(described_class).to have_received(:`).with(/task-abc-123\b/)
    end
  end

  describe '.commit_changes' do
    it 'runs git add and commit' do
      described_class.commit_changes('abc-123', 'Fix bug')
      expect(described_class).to have_received(:`).with('git add .')
      expect(described_class).to have_received(:`).with(/git commit.*ares: task-abc-123/)
    end
  end
end
