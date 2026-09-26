require "json"

module Llm
  class JsonParser
    def self.parse(text)
      return {} if text.blank?

      stripped = text.to_s.strip
      stripped = stripped.sub(/\A```(?:json)?\s*/i, "").sub(/```\z/, "").strip
      JSON.parse(stripped)
    rescue JSON::ParserError
      if (match = stripped.match(/\{.*\}/m))
        JSON.parse(match[0])
      else
        {}
      end
    end
  end
end
