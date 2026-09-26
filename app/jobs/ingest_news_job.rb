class IngestNewsJob < ApplicationJob
  queue_as :default

  def perform
    created_ids = News::Ingestor.new.call
    Rails.logger.info("[IngestNewsJob] enqueued analysis for #{created_ids.size} new stories")
    SelectStoriesJob.set(wait: 2.minutes).perform_later if created_ids.any?
    created_ids
  end
end
