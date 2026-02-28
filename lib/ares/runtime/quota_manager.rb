# frozen_string_literal: true

module Ares
  module Runtime
    class QuotaManager
      GLOBAL_DIR = File.expand_path('~/.ares')
      QUOTA_FILE = File.expand_path("#{GLOBAL_DIR}/.quota.json", __dir__)
      LIMITS = { claude: 50, codex: 100 }.freeze

      def self.usage
        data = load_data
        today = Date.today.to_s
        {
          claude: data[today] || 0,
          codex: 0 # Tracked separately or placeholder
        }
      end

      def self.increment_usage(engine)
        return unless engine == :claude

        data = load_data
        today = Date.today.to_s

        data[today] ||= 0
        data[today] += 1

        File.write(QUOTA_FILE, JSON.pretty_generate(data))
      end

      def self.remaining_quota
        LIMITS[:claude] - usage[:claude]
      end

      def self.quota_exceeded?
        remaining_quota <= 0
      end

      def self.load_data
        return {} unless File.exist?(QUOTA_FILE)

        JSON.parse(File.read(QUOTA_FILE))
      rescue JSON::ParserError
        {}
      end
    end
  end
end
