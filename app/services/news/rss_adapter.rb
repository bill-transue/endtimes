require "rss"
require "json"

module News
  class RssAdapter
    Article = News::GnewsAdapter::Article

    def initialize(fetcher: HttpFetcher.new)
      @fetcher = fetcher
    end

    def fetch
      FeedSource.enabled_rss.find_each.flat_map { |source| fetch_source(source) }
    end

    def fetch_source(source)
      response = @fetcher.get(source.url, timeout: 20)
      return [] unless response.is_a?(Net::HTTPSuccess)

      feed = RSS::Parser.parse(response.body, false)
      items = feed.respond_to?(:items) ? feed.items : []
      items.first(15).filter_map { |item| to_article(item, source) }
    rescue RSS::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, ArgumentError => error
      Rails.logger.warn("[RssAdapter] #{source.name}: #{error.class}: #{error.message}")
      []
    end

    private
      def to_article(item, source)
        link = item_link(item)
        title = item.title.to_s
        return if link.blank? || title.blank?

        Article.new(
          url: CanonicalUrl.call(link),
          title: title.squish,
          description: item_description(item),
          excerpt: item_description(item).truncate(500),
          source_name: source.name,
          image_url: nil,
          published_at: item_date(item),
          raw: { "source_id" => source.id, "link" => link }
        )
      end

      def item_link(item)
        if item.respond_to?(:link) && item.link.present?
          item.link.respond_to?(:href) ? item.link.href : item.link.to_s
        elsif item.respond_to?(:url)
          item.url.to_s
        end
      end

      def item_description(item)
        raw = if item.respond_to?(:summary) && item.summary.present?
          item.summary.to_s
        elsif item.respond_to?(:description)
          item.description.to_s
        elsif item.respond_to?(:content) && item.content.present?
          item.content.to_s
        else
          ""
        end
        ActionView::Base.full_sanitizer.sanitize(raw).to_s.squish
      end

      def item_date(item)
        value = item.respond_to?(:pubDate) ? item.pubDate : item.respond_to?(:dc_date) ? item.dc_date : nil
        value = item.updated if value.nil? && item.respond_to?(:updated)
        value&.to_time
      rescue NoMethodError
        nil
      end
  end
end
