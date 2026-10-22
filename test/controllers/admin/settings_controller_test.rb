require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    EditorialSetting.delete_all
    FeedSource.delete_all
  end

  test "requires http basic" do
    get admin_settings_path
    assert_response :unauthorized

    patch admin_settings_path, params: { editorial_setting: { focus: "broad" } }
    assert_response :unauthorized
    assert EditorialSetting.current.end_times?
  end

  test "shows and updates editorial settings" do
    get admin_settings_path, headers: auth_headers
    assert_response :success
    assert_match "End times leaning", @response.body

    patch admin_settings_path, headers: auth_headers, params: {
      editorial_setting: {
        focus: "mix",
        gnews_queries_text: "Israel OR Jerusalem\npersecution",
        min_prophecy_relevance: "0.5",
        daily_publish_cap: "4"
      }
    }
    assert_redirected_to admin_settings_path

    setting = EditorialSetting.current
    assert setting.mix?
    assert_equal [ "Israel OR Jerusalem", "persecution" ], setting.query_list
    assert_in_delta 0.5, setting.min_prophecy_relevance
    assert_equal 4, setting.effective_daily_publish_cap
  end

  test "invalid settings re-render" do
    patch admin_settings_path, headers: auth_headers, params: { editorial_setting: { min_prophecy_relevance: "2" } }
    assert_response :unprocessable_entity
    assert_in_delta 0.35, EditorialSetting.current.min_prophecy_relevance
  end

  test "story queue links to settings" do
    get admin_stories_path, headers: auth_headers
    assert_select "a[href=?]", admin_settings_path
  end

  test "toggles feed sources" do
    source = FeedSource.create!(name: "Times of Israel", url: "https://www.timesofisrael.com/feed/", kind: :rss, enabled: false)

    post toggle_admin_feed_source_path(source), headers: auth_headers
    assert_redirected_to admin_settings_path
    assert source.reload.enabled?
  end

  private
    def auth_headers
      encoded = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "endtimes")
      { "HTTP_AUTHORIZATION" => encoded }
    end
end
