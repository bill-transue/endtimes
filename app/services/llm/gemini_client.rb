require "cgi"
require "json"

module Llm
  class GeminiClient < LlmClient
    DEFAULT_MODEL = "gemini-2.5-flash-lite"

    def analyze_story(input)
      request(system: StoryAnalyzer::SYSTEM_PROMPT, user: StoryAnalyzer.user_prompt(input))
    end

    def select_stories(input)
      request(system: StorySelector::SYSTEM_PROMPT, user: StorySelector.user_prompt(input))
    end

    private
      def request(system:, user:)
        key = ENV["GEMINI_API_KEY"].to_s
        model = ENV.fetch("LLM_MODEL", DEFAULT_MODEL)
        url = "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{CGI.escape(key)}"
        body = {
          systemInstruction: { parts: [ { text: system } ] },
          contents: [ { role: "user", parts: [ { text: user } ] } ],
          generationConfig: { temperature: 0.2, responseMimeType: "application/json" }
        }

        response = HttpFetcher.new.post_json(url, body: body, timeout: 45)
        raw_text = response.body.to_s
        unless response.is_a?(Net::HTTPSuccess)
          return Result.new(ok: false, payload: {}, raw: { "http_status" => response.code, "body" => raw_text }, model: model, error: "Gemini HTTP #{response.code}")
        end

        envelope = JSON.parse(raw_text)
        text = envelope.dig("candidates", 0, "content", "parts", 0, "text").to_s
        payload = JsonParser.parse(text)
        Result.new(ok: payload.present?, payload: payload, raw: envelope, model: model, error: payload.present? ? nil : "empty JSON")
      rescue JSON::ParserError, SocketError, Timeout::Error, Errno::ECONNREFUSED => error
        Result.new(ok: false, payload: {}, raw: { "error" => error.message }, model: model, error: error.message)
      end
  end
end
