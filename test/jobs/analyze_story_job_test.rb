require "test_helper"

class AnalyzeStoryJobTest < ActiveSupport::TestCase
  setup do
    seed_verse!(book: "Amos", chapter: 5, verse: 24, text: "But let justice roll on like rivers.")
    seed_verse!(book: "Exodus", chapter: 20, verse: 17, text: "You shall not covet.")
    seed_verse!(book: "Proverbs", chapter: 14, verse: 31, text: "He who oppresses the poor shows contempt for his Maker.")
  end

  test "mock llm writes analysis and marks analyzed without live http" do
    story = create_story(title: "Prosecutors charge a favorite with hidden bribes")

    assert_no_http do
      AnalyzeStoryJob.perform_now(story.id)
    end

    story.reload
    assert story.analyzed?
    analysis = story.biblical_analysis
    assert_includes analysis.theme_list, "sin"
    assert_not analysis.stretch?
    assert analysis.verse_ref_list.any?
    looked = analysis.looked_up_verses
    assert looked.any?(&:found)
  end

  test "war stories are marked stretch and not forced as sure prophecy" do
    story = create_story(title: "Overnight missile strikes jolt a ceasefire")
    AnalyzeStoryJob.perform_now(story.id)
    analysis = story.reload.biblical_analysis
    assert analysis.stretch?
    assert analysis.prophecy_relevance < 0.8
    assert_match(/stretch|not proven|decoder/i, analysis.caveat)
  end

  private
    def assert_no_http(&block)
      WebMock.reset_executed_requests!
      block.call
      assert_empty WebMock::RequestRegistry.instance.requested_signatures.hash
    end
end
