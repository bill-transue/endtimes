require "test_helper"

class SelectStoriesJobTest < ActiveSupport::TestCase
  test "publishes under the daily cap and holds the rest" do
    ClimateSelect.with_cap(1) do
      keep = analyzed_story(title: "Aid groups warn famine is spreading", description: "hungry displaced families")
      stretch = analyzed_story(title: "War drums and rumors of missiles", description: "war missile ukraine")

      SelectStoriesJob.perform_now

      assert keep.reload.published?
      assert stretch.reload.held?
    end
  end

  private
    def analyzed_story(title:, description:)
      story = create_story(title: title, description: description, status: :ingested)
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
