require "json"
require "date"

class QuotaManager
  QUOTA_FILE = File.expand_path("../../.quota.json", __dir__)
  DAILY_CLAUDE_LIMIT = 50 # Example limit

  def self.increment_usage(engine)
    return unless engine == :claude

    data = load_data
    today = Date.today.to_s

    data[today] ||= 0
    data[today] += 1

    File.write(QUOTA_FILE, JSON.pretty_generate(data))
  end

  def self.remaining_quota
    data = load_data
    today = Date.today.to_s
    DAILY_CLAUDE_LIMIT - (data[today] || 0)
  end

  def self.quota_exceeded?
    remaining_quota <= 0
  end

  private

  def self.load_data
    return {} unless File.exist?(QUOTA_FILE)
    JSON.parse(File.read(QUOTA_FILE))
  rescue JSON::ParserError
    {}
  end
end
