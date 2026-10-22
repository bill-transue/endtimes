require "test_helper"

class StoryAnalyzerTest < ActiveSupport::TestCase
  setup do
    EditorialSetting.delete_all
  end

  test "end times prompt looks for Olivet themes and drops the 0.4 ceiling" do
    prompt = StoryAnalyzer.system_prompt("end_times")

    assert_match "Olivet Discourse", prompt
    assert_match "persecution of the church", prompt
    assert_match "nations", prompt
    assert_no_match(/well below 0\.4/, prompt)
  end

  test "broad prompt keeps the original ceiling" do
    assert_match(/Most stories should be well below 0\.4/, StoryAnalyzer.system_prompt("broad"))
    assert_no_match(/Olivet/, StoryAnalyzer.system_prompt("broad"))
  end

  test "every focus keeps stretch flags and the no-prediction rule" do
    EditorialSetting::FOCUS_LABELS.each_key do |focus|
      prompt = StoryAnalyzer.system_prompt(focus)
      assert_match "Never claim the Bible predicted this exact event.", prompt
      assert_match "stretch=true", prompt
      assert_match "Antichrist", prompt
    end
  end

  test "prompt defaults to the saved focus" do
    EditorialSetting.current.update!(focus: :broad)
    assert_equal StoryAnalyzer.system_prompt("broad"), StoryAnalyzer.system_prompt
  end

  test "passes the saved focus to the client" do
    EditorialSetting.current.update!(focus: :mix)
    client = RecordingClient.new
    StoryAnalyzer.new(client: client).call(create_story)

    assert_equal "mix", client.inputs.last[:focus]
  end

  test "mock leans toward genuine prophecy links under end times" do
    analysis = analyze("Gunmen attack a church and kill Christians in Nigeria", focus: :end_times)
    assert_includes analysis.theme_list, "prophecy"
    assert_not analysis.stretch?
    assert_operator analysis.prophecy_relevance, :>=, 0.35

    analysis = analyze("Talks on Jerusalem holy sites stall", focus: :end_times)
    assert_includes analysis.theme_list, "nations"
    assert_not analysis.stretch?
    assert analysis.connection_list.any? { |row| row[:stretch] }, "thin Jerusalem links stay marked stretch"
  end

  test "mock keeps war and flood stories honest under end times" do
    war = analyze("Overnight missile strikes jolt a ceasefire", focus: :end_times)
    assert war.stretch?
    assert_match(/not proven/, war.caveat)

    flood = analyze("Floodwaters cut a town off from food", focus: :end_times)
    assert_not_includes flood.theme_list, "prophecy"
  end

  test "mock analyzes prophecy claims without endorsing them" do
    analysis = analyze("Activists bring red heifers for a third temple", focus: :end_times)
    assert_includes analysis.theme_list, "prophecy"
    assert_match(/do not endorse/, analysis.caveat)
  end

  test "mock keeps the original broad reading" do
    analysis = analyze("Talks on Jerusalem holy sites stall in Israel", focus: :broad)
    assert analysis.stretch?
    assert_in_delta 0.42, analysis.prophecy_relevance
  end

  private
    def analyze(title, focus:)
      EditorialSetting.current.update!(focus: focus)
      StoryAnalyzer.new(client: Llm::MockClient.new).call(create_story(title: title, description: ""))
    end

    class RecordingClient < Llm::MockClient
      attr_reader :inputs

      def analyze_story(input)
        (@inputs ||= []) << input
        super
      end
    end
end
