require "test_helper"

class IngestorTest < ActiveSupport::TestCase
  RSS_XML = <<~XML
    <?xml version="1.0"?>
    <rss version="2.0">
      <channel>
        <title>World</title>
        <item>
          <title>Floodwaters cut a town off from food</title>
          <link>https://www.bbc.com/news/world-123?utm_medium=rss</link>
          <description>Families wait on roofs for boats.</description>
          <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
        </item>
      </channel>
    </rss>
  XML

  setup do
    FeedSource.create!(name: "BBC World", url: "https://feeds.example.test/world.xml", kind: :rss, enabled: true)
  end

  test "skips gnews without NEWS_API_KEY and ingests rss" do
    ClimateControl.stub_keyless do
      stub_request(:get, "https://feeds.example.test/world.xml").to_return(status: 200, body: RSS_XML, headers: { "Content-Type" => "application/rss+xml" })

      refute News::GnewsAdapter.new(api_key: "").enabled?
      created = News::Ingestor.new(gnews: News::GnewsAdapter.new(api_key: ""), rss: News::RssAdapter.new).call

      assert_equal 1, created.size
      story = Story.find(created.first)
      assert_equal "https://www.bbc.com/news/world-123", story.url
      assert story.rss?
      assert story.ingested?
      assert_enqueued_with(job: AnalyzeStoryJob, args: [ story.id ])
    end
  end

  test "gnews upserts articles when keyed" do
    payload = {
      "articles" => [
        {
          "title" => "Court files describe a trail of bribes",
          "description" => "A ministry aide took cash for contracts.",
          "content" => "excerpt only",
          "url" => "https://www.reuters.com/world/bribes",
          "image" => "https://www.reuters.com/image.jpg",
          "publishedAt" => "2024-01-02T08:00:00Z",
          "source" => { "name" => "Reuters" }
        }
      ]
    }
    stub_request(:get, %r{https://gnews.io/api/v4/search}).to_return(status: 200, body: payload.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://feeds.example.test/world.xml").to_return(status: 200, body: RSS_XML)

    created = News::Ingestor.new(
      gnews: News::GnewsAdapter.new(api_key: "test-key"),
      rss: News::RssAdapter.new
    ).call

    assert created.size >= 1
    gnews_story = Story.find_by(url: "https://www.reuters.com/world/bribes")
    assert gnews_story.gnews?
    assert_equal "Reuters", gnews_story.source_name
  end
end

module ClimateControl
  def self.stub_keyless
    prior = ENV["NEWS_API_KEY"]
    ENV.delete("NEWS_API_KEY")
    yield
  ensure
    ENV["NEWS_API_KEY"] = prior if prior
  end
end
