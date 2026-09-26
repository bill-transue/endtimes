require "json"

module Llm
  class OpenaiClient < LlmClient
    DEFAULT_MODEL = "gpt-4o-mini"

    def analyze_story(input)
      request(system: StoryAnalyzer::SYSTEM_PROMPT, user: StoryAnalyzer.user_prompt(input))
    end

    def select_stories(input)
      request(system: StorySelector::SYSTEM_PROMPT, user: StorySelector.user_prompt(input))
    end

    private
      def request(system:, user:)
        model = ENV.fetch("LLM_MODEL", DEFAULT_MODEL)
        url = "https://api.openai.com/v1/chat/completions"
        headers = {
          "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
        }
        body = {
          model: model,
          temperature: 0.2,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: system },
            { role: "user", content: user }
          ]
        }

        response = HttpFetcher.new.post_json(url, body: body, headers: headers, timeout: 45)
        raw_text = response.body.to_s
        unless response.is_a?(Net::HTTPSuccess)
          return Result.new(ok: false, payload: {}, raw: { "http_status" => response.code, "body" => raw_text }, model: model, error: "OpenAI HTTP #{response.code}")
        end

        envelope = JSON.parse(raw_text)
        text = envelope.dig("choices", 0, "message", "content").to_s
        payload = JsonParser.parse(text)
        Result.new(ok: payload.present?, payload: payload, raw: envelope, model: model, error: payload.present? ? nil : "empty JSON")
      rescue JSON::ParserError, SocketError, Timeout::Error, Errno::ECONNREFUSED => error
        Result.new(ok: false, payload: {}, raw: { "error" => error.message }, model: model, error: error.message)
      end
  end
end
