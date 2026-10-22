require "test_helper"

class StorySelectorTest < ActiveSupport::TestCase
  setup do
    EditorialSetting.delete_all
  end

  test "end times ranks genuine prophecy above a generic hope reading" do
    focus!(:end_times)
    hope = analyzed_story(title: "Neighbors plant a community garden")
    persecution = analyzed_story(title: "Gunmen attack a church and kill Christians", source_name: "Morning Star News")

    decisions = selector(cap: 1).call

    assert_equal [ persecution.id ], decisions["publish"]
    assert persecution.reload.published?
    assert hope.reload.held?
  end

  test "end times holds stretch takes even with room under the cap" do
    focus!(:end_times)
    war = analyzed_story(title: "Overnight missile strikes jolt a ceasefire")

    selector(cap: 5).call

    assert war.reload.held?
  end

  test "end times gives stretch-but-relevant stories a small bonus over unrelated stretch" do
    focus!(:end_times)
    selector = selector(cap: 5)
    relevant = story_with_analysis(themes: %w[nations prophecy], prophecy_relevance: 0.5, stretch: true)
    unrelated = story_with_analysis(themes: %w[hope], prophecy_relevance: 0.1, stretch: true)
    genuine = story_with_analysis(themes: %w[prophecy], prophecy_relevance: 0.6, stretch: false)

    assert_operator selector.heuristic_score(relevant), :>, selector.heuristic_score(unrelated)
    assert_operator selector.heuristic_score(genuine), :>, selector.heuristic_score(relevant)
  end

  test "end times cuts the hope and wisdom bonus" do
    hope = story_with_analysis(themes: %w[hope wisdom], prophecy_relevance: 0.05, stretch: false)
    bare = story_with_analysis(themes: %w[idolatry], prophecy_relevance: 0.05, stretch: false)

    focus!(:end_times)
    assert_in_delta selector.heuristic_score(bare), selector.heuristic_score(hope), 0.001
    focus!(:broad)
    assert_operator selector.heuristic_score(hope), :>, selector.heuristic_score(bare)
  end

  test "end times moves stretch picks from an llm to hold and backfills" do
    focus!(:end_times)
    war = analyzed_story(title: "Overnight missile strikes jolt a ceasefire")
    persecution = analyzed_story(title: "Gunmen attack a church and kill Christians")
    client = ScriptedClient.new("publish" => [ war.id ], "hold" => [ persecution.id ], "reject" => [])

    decisions = selector(cap: 1, client: client).call

    assert_equal [ persecution.id ], decisions["publish"]
    assert war.reload.held?
    assert persecution.reload.published?
  end

  test "mix publishes the prophecy floor even when broad scoring prefers hope" do
    focus!(:mix)
    aid = analyzed_story(title: "Aid groups warn of displaced families", source_name: "Reuters")
    persecution = analyzed_story(title: "Gunmen attack a church and kill Christians", source_name: "Morning Star News")
    selector = selector(cap: 1)
    assert_operator selector.heuristic_score(aid), :>, selector.heuristic_score(persecution)

    selector.call

    assert persecution.reload.published?
    assert aid.reload.held?
  end

  test "mix floor respects min prophecy relevance" do
    focus!(:mix)
    EditorialSetting.current.update!(min_prophecy_relevance: 0.9)
    aid = analyzed_story(title: "Aid groups warn of displaced families", source_name: "Reuters")
    persecution = analyzed_story(title: "Gunmen attack a church and kill Christians", source_name: "Morning Star News")

    selector(cap: 1).call

    assert aid.reload.published?
    assert persecution.reload.held?
  end

  test "broad keeps the original hope-first behavior" do
    focus!(:broad)
    aid = analyzed_story(title: "Aid groups warn famine is spreading", source_name: "Reuters")
    israel = analyzed_story(title: "Talks on Jerusalem holy sites stall in Israel", source_name: "Reuters")

    selector(cap: 1).call

    assert aid.reload.published?
    assert israel.reload.held?
  end

  test "selector prompts change with focus and keep the no-prediction rule" do
    assert_match "genuine last-days connections", StorySelector.system_prompt("end_times")
    assert_match "over a generic hope or wisdom reading", StorySelector.system_prompt("end_times")
    assert_match "prophecy floor", StorySelector.system_prompt("mix")
    assert_match "A justice or hope story with a clear verse", StorySelector.system_prompt("broad")
    EditorialSetting::FOCUS_LABELS.each_key do |focus|
      assert_match "Never publish an analysis that claims the Bible predicted this exact event.", StorySelector.system_prompt(focus)
    end
  end

  test "user prompt includes min prophecy and floor" do
    prompt = StorySelector.user_prompt(cap: 3, min_prophecy_relevance: 0.35, prophecy_floor: 2, stories: [])
    assert_match "Daily publish remaining: 3", prompt
    assert_match "Minimum prophecy relevance: 0.35", prompt
    assert_match "Prophecy floor still needed today: 2", prompt
  end

  private
    def focus!(focus)
      EditorialSetting.current.update!(focus: focus)
    end

    def selector(cap: 5, client: Llm::MockClient.new)
      StorySelector.new(client: client, setting: EditorialSetting.current, cap: cap)
    end

    def analyzed_story(title:, source_name: "Reuters")
      story = create_story(title: title, description: "", source_name: source_name)
      StoryAnalyzer.new(client: Llm::MockClient.new).call(story)
      story.reload
    end

    def story_with_analysis(themes:, prophecy_relevance:, stretch:)
      story = create_story(status: :analyzed, source_name: "Wire")
      story.create_biblical_analysis!(summary: "s", themes: themes, prophecy_relevance: prophecy_relevance, stretch: stretch)
      story
    end

    class ScriptedClient < LlmClient
      def initialize(payload)
        @payload = payload
      end

      def select_stories(_input)
        Result.new(ok: true, payload: @payload, raw: @payload, model: "scripted", error: nil)
      end
    end
end
