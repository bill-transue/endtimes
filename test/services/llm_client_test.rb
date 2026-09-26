require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  test "builds mock when no keys" do
    prior_g, prior_o, prior_p = ENV["GEMINI_API_KEY"], ENV["OPENAI_API_KEY"], ENV["LLM_PROVIDER"]
    ENV.delete("GEMINI_API_KEY")
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("LLM_PROVIDER")

    client = LlmClient.build
    assert_kind_of Llm::MockClient, client
    assert client.mock?
  ensure
    ENV["GEMINI_API_KEY"] = prior_g if prior_g
    ENV["OPENAI_API_KEY"] = prior_o if prior_o
    ENV["LLM_PROVIDER"] = prior_p if prior_p
  end

  test "json parser strips fences" do
    parsed = Llm::JsonParser.parse("```json\n{\"summary\":\"ok\"}\n```")
    assert_equal "ok", parsed["summary"]
  end
end
