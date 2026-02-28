# frozen_string_literal: true

RSpec.describe Ares::Runtime::QuotaManager do
  let(:quota_file) { described_class::QUOTA_FILE }
  let(:today) { Date.today.to_s }

  before do
    File.delete(quota_file) if File.exist?(quota_file)
  end

  after do
    File.delete(quota_file) if File.exist?(quota_file)
  end

  describe '.usage' do
    it 'returns zero for claude when no usage recorded' do
      expect(described_class.usage[:claude]).to eq(0)
    end

    it 'returns recorded usage when quota file exists' do
      File.write(quota_file, { today => 5 }.to_json)
      expect(described_class.usage[:claude]).to eq(5)
    end
  end

  describe '.remaining_quota' do
    it 'returns full limit when no usage' do
      expect(described_class.remaining_quota).to eq(described_class::LIMITS[:claude])
    end

    it 'returns reduced quota when usage exists' do
      File.write(quota_file, { today => 10 }.to_json)
      expect(described_class.remaining_quota).to eq(described_class::LIMITS[:claude] - 10)
    end
  end

  describe '.quota_exceeded?' do
    it 'returns false when usage is below limit' do
      expect(described_class.quota_exceeded?).to be false
    end

    it 'returns true when usage equals or exceeds limit' do
      File.write(quota_file, { today => described_class::LIMITS[:claude] }.to_json)
      expect(described_class.quota_exceeded?).to be true
    end
  end

  describe '.increment_usage' do
    it 'increments claude usage for today' do
      described_class.increment_usage(:claude)
      expect(described_class.usage[:claude]).to eq(1)
    end

    it 'does nothing for non-claude engine' do
      described_class.increment_usage(:codex)
      expect(described_class.usage[:claude]).to eq(0)
    end
  end
end
