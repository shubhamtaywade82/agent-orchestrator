# frozen_string_literal: true

require "net/http"
require "json"

module Ares
  module LocalAI
    class OllamaClient
      URL = "http://localhost:11434/api/generate"

      def generate(prompt)
        body = {
          model: "qwen2.5:7b",
          prompt: prompt,
          stream: false
        }

        res = Net::HTTP.post(
          URI(URL),
          body.to_json,
          "Content-Type" => "application/json"
        )

        JSON.parse(res.body)["response"]
      end
    end
  end
end
