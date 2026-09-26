module News
  class Ingestor
    def initialize(gnews: News::GnewsAdapter.new, rss: News::RssAdapter.new)
      @gnews = gnews
      @rss = rss
    end

    def call
      created_ids = []
      gnews_articles = @gnews.fetch
      rss_articles = @rss.fetch

      gnews_articles.each { |article| created_ids << upsert(article, :gnews) }
      rss_articles.each { |article| created_ids << upsert(article, :rss) }

      created_ids.compact
    end

    def upsert(article, source_kind)
      url = CanonicalUrl.call(article.url)
      return if url.blank? || article.title.blank?

      story = Story.find_or_initialize_by(url: url)
      newly_created = story.new_record?

      story.title = article.title if story.title.blank? || newly_created
      story.description = article.description.presence || story.description
      story.source_name = article.source_name.presence || story.source_name || "Unknown"
      story.source_kind = source_kind if newly_created
      story.image_url = article.image_url if article.image_url.present?
      story.published_at = article.published_at || story.published_at || Time.current
      story.status = :ingested if newly_created
      payload = story.raw_payload || {}
      payload["excerpt"] = article.excerpt if article.excerpt.present?
      payload["source"] = source_kind.to_s
      payload["raw"] = article.raw
      story.raw_payload = payload
      story.save!

      if newly_created
        AnalyzeStoryJob.perform_later(story.id)
        story.id
      end
    end
  end
end
