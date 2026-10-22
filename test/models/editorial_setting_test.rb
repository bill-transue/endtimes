require "test_helper"

class EditorialSettingTest < ActiveSupport::TestCase
  setup do
    EditorialSetting.delete_all
  end

  test "current creates a single end-times row with seeded queries" do
    setting = EditorialSetting.current

    assert setting.end_times?
    assert_in_delta 0.35, setting.min_prophecy_relevance
    assert_equal EditorialSetting::END_TIMES_GNEWS_QUERIES, setting.query_list
    assert_equal setting, EditorialSetting.current
    assert_equal 1, EditorialSetting.count
  end

  test "daily cap falls back to DAILY_PUBLISH_CAP" do
    setting = EditorialSetting.current
    with_env("DAILY_PUBLISH_CAP", "7") do
      assert_equal 7, setting.effective_daily_publish_cap
      setting.update!(daily_publish_cap: 3)
      assert_equal 3, setting.effective_daily_publish_cap
    end
  end

  test "queries text is split per line and blank list falls back to focus defaults" do
    setting = EditorialSetting.current
    setting.update!(gnews_queries_text: "  Israel OR Gaza \n\n\"red heifer\"\nIsrael OR Gaza\n")
    assert_equal [ "Israel OR Gaza", "\"red heifer\"" ], setting.query_list

    setting.update!(gnews_queries_text: "", focus: :broad)
    assert_equal EditorialSetting::BROAD_GNEWS_QUERIES, setting.query_list
  end

  test "rejects out of range prophecy relevance and unknown focus" do
    setting = EditorialSetting.current
    assert_not setting.update(min_prophecy_relevance: 1.5)
    setting.reload
    assert_not setting.update(focus: "decoder")
  end

  private
    def with_env(key, value)
      prior = ENV[key]
      ENV[key] = value
      yield
    ensure
      prior ? ENV[key] = prior : ENV.delete(key)
    end
end
