require "test_helper"

class StoriesControllerTest < ActionDispatch::IntegrationTest
  test "feed lists published stories and hides held ones" do
    published = create_story(title: "Published famine warning", status: :published, description: "hungry families")
    create_story(url: "https://example.com/held", title: "Held war take", status: :held)

    get root_path
    assert_response :success
    assert_select "h1", /Today’s news/
    assert_match published.title, @response.body
    assert_no_match "Held war take", @response.body
  end

  test "show page links out and does not reprint a body" do
    story = create_story(title: "A church opens its hall to evacuees", status: :ingested, description: "flood aid hope")
    AnalyzeStoryJob.perform_now(story.id)
    story.publish!

    get story_path(story)
    assert_response :success
    assert_select "a[href=?]", story.url
    assert_match "We do not reprint the article", @response.body
    assert_no_match "FULL ARTICLE BODY", @response.body
  end

  test "unpublished stories 404" do
    story = create_story(status: :held)
    get story_path(story)
    assert_response :not_found
  end

  test "about explains methodology" do
    get about_path
    assert_response :success
    assert_match "not a decoder", @response.body
  end

  test "empty feed state" do
    get root_path
    assert_response :success
    assert_match "No published stories yet", @response.body
  end
end
