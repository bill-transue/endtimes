class LlmClient
  Result = Struct.new(:ok, :payload, :raw, :model, :error, keyword_init: true)

  def self.build
    provider = ENV["LLM_PROVIDER"].presence || inferred_provider
    case provider
    when "gemini" then Llm::GeminiClient.new
    when "openai" then Llm::OpenaiClient.new
    else
      Llm::MockClient.new
    end
  end

  def self.inferred_provider
    if ENV["GEMINI_API_KEY"].present?
      "gemini"
    elsif ENV["OPENAI_API_KEY"].present?
      "openai"
    else
      "mock"
    end
  end

  def analyze_story(input)
    raise NotImplementedError
  end

  def select_stories(input)
    raise NotImplementedError
  end

  def mock?
    false
  end
end
