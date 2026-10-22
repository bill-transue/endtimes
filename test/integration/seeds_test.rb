require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  setup do
    EditorialSetting.delete_all
    FeedSource.delete_all
    BibleVerse.delete_all
  end

  test "seeds are idempotent and preserve admin edits" do
    silently { load Rails.root.join("db/seeds.rb") }

    setting = EditorialSetting.current
    assert setting.end_times?
    assert_equal EditorialSetting::END_TIMES_GNEWS_QUERIES, setting.query_list
    %w[Times\ of\ Israel Jerusalem\ Post International\ Christian\ Concern Morning\ Star\ News].each do |name|
      assert FeedSource.find_by(name: name)&.enabled?, "#{name} should be seeded and enabled"
    end

    setting.update!(focus: :broad, gnews_queries_text: "church")
    FeedSource.find_by(name: "Jerusalem Post").update!(enabled: false)
    counts = [ EditorialSetting.count, FeedSource.count, BibleVerse.count, Story.count ]

    silently { load Rails.root.join("db/seeds.rb") }

    assert_equal counts, [ EditorialSetting.count, FeedSource.count, BibleVerse.count, Story.count ]
    assert EditorialSetting.current.broad?
    assert_equal [ "church" ], EditorialSetting.current.query_list
    assert_not FeedSource.find_by(name: "Jerusalem Post").enabled?
  end

  private
    def silently
      original = $stdout
      $stdout = StringIO.new
      yield
    ensure
      $stdout = original
    end
end
