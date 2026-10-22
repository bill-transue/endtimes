require "test_helper"

class SelectStoriesJobTest < ActiveSupport::TestCase
  setup do
    EditorialSetting.delete_all
  end

  test "publishes under the daily cap and holds the rest" do
    ClimateSelect.with_cap(1) do
      keep = analyzed_story(title: "Aid groups warn famine is spreading", description: "hungry displaced families")
      stretch = analyzed_story(title: "War drums and rumors of missiles", description: "war missile ukraine")

      SelectStoriesJob.perform_now

      assert keep.reload.published?
      assert stretch.reload.held?
    end
  end

  test "reshuffle reconsiders recent auto-held stories under the new focus" do
    EditorialSetting.current.update!(focus: :broad, daily_publish_cap: 1)
    aid = analyzed_story(title: "Aid groups warn of displaced families", description: "")
    persecution = analyzed_story(title: "Gunmen attack a church and kill Christians", description: "", source_name: "Morning Star News")
    SelectStoriesJob.perform_now
    assert aid.reload.published?
    assert persecution.reload.held?

    EditorialSetting.current.update!(focus: :end_times, daily_publish_cap: 2)
    SelectStoriesJob.perform_now(reshuffle: true)

    assert persecution.reload.published?
    assert aid.reload.published?, "already-published stories stay live"
  end

  test "reshuffle never unpublishes and leaves editor and stale holds alone" do
    EditorialSetting.current.update!(focus: :end_times, daily_publish_cap: 10)
    live = analyzed_story(title: "Neighbors plant a community garden", description: "")
    live.publish!
    editor_held = analyzed_story(title: "Gunmen attack a church and kill Christians", description: "")
    editor_held.editor_set_status!(:held)
    stale = analyzed_story(title: "Christians abducted in a village raid", description: "", published_at: 5.days.ago)
    stale.hold!
    fresh = analyzed_story(title: "Pastor arrested as persecution of believers widens", description: "")
    fresh.hold!

    assert_equal [ fresh.id ], Story.reshuffle_candidates.pluck(:id)

    SelectStoriesJob.perform_now(reshuffle: true)

    assert live.reload.published?
    assert editor_held.reload.held?
    assert stale.reload.held?
    assert fresh.reload.published?
  end

  private
    def analyzed_story(title:, description:, source_name: "Reuters", published_at: Time.current)
      story = create_story(title: title, description: description, status: :ingested, source_name: source_name, published_at: published_at)
      AnalyzeStoryJob.perform_now(story.id)
      story.reload
    end
end

module ClimateSelect
  def self.with_cap(value)
    prior = ENV["DAILY_PUBLISH_CAP"]
    ENV["DAILY_PUBLISH_CAP"] = value.to_s
    yield
  ensure
    if prior
      ENV["DAILY_PUBLISH_CAP"] = prior
    else
      ENV.delete("DAILY_PUBLISH_CAP")
    end
  end
end
