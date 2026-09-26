require "test_helper"

class StoryTest < ActiveSupport::TestCase
  test "upserts by canonical url and keeps status" do
    first = create_story(url: "https://www.bbc.com/news/world")
    duplicate = News::Ingestor.new(gnews: stub_gnews, rss: stub_rss).upsert(
      News::GnewsAdapter::Article.new(
        url: "https://www.bbc.com/news/world?utm_source=other",
        title: "Updated title",
        description: "desc",
        excerpt: "excerpt",
        source_name: "BBC",
        image_url: nil,
        published_at: Time.current,
        raw: {}
      ),
      :rss
    )

    assert_nil duplicate
    assert_equal 1, Story.where(url: "https://www.bbc.com/news/world").count
    assert first.reload.ingested?
  end

  test "status machine publish hold reject" do
    story = create_story(status: :analyzed)
    story.publish!
    assert story.published?
    story.hold!
    assert story.held?
    story.reject!
    assert story.rejected?
  end

  private
    def stub_gnews
      fake = Object.new
      def fake.fetch = []
      fake
    end

    def stub_rss
      fake = Object.new
      def fake.fetch = []
      fake
    end
end
