class SelectStoriesJob < ApplicationJob
  queue_as :default

  def perform
    StorySelector.new.call
  end
end
