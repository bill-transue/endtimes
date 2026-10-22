class SelectStoriesJob < ApplicationJob
  queue_as :default

  def perform(reshuffle: false)
    stories = reshuffle ? Story.reshuffle_candidates : Story.awaiting_selection
    StorySelector.new.call(stories.to_a)
  end
end
