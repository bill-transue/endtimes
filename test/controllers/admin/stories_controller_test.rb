require "test_helper"

class Admin::StoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = create_story(status: :analyzed, title: "Editors must decide this bribe case")
  end

  test "requires http basic" do
    get admin_stories_path
    assert_response :unauthorized
  end

  test "publish hold reject overrides" do
    get admin_stories_path, headers: auth_headers
    assert_response :success
    assert_match @story.title, @response.body

    post publish_admin_story_path(@story), headers: auth_headers
    assert_redirected_to admin_stories_path
    assert @story.reload.published?

    post hold_admin_story_path(@story), headers: auth_headers
    assert @story.reload.held?

    post reject_admin_story_path(@story), headers: auth_headers
    assert @story.reload.rejected?
  end

  private
    def auth_headers
      encoded = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "endtimes")
      { "HTTP_AUTHORIZATION" => encoded }
    end
end
