class AnalyzeStoryJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(story_id)
    story = Story.find_by(id: story_id)
    return if story.nil?
    return unless story.ingested? || story.analyzed?

    StoryAnalyzer.new.call(story)
  end
end
