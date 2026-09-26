module News
  class GnewsAdapter
    SEARCH_URL = "https://gnews.io/api/v4/search"
    QUERIES = [
      'justice OR refugees OR famine OR "human rights"',
      "church OR Christianity OR persecution OR clergy",
      "war OR ceasefire OR peace OR genocide",
      "corruption OR poverty OR greed OR scandal"
    ].freeze

    Article = Struct.new(:url, :title, :description, :excerpt, :source_name, :image_url, :published_at, :raw, keyword_init: true)

    def initialize(api_key: ENV["NEWS_API_KEY"], fetcher: HttpFetcher.new)
      @api_key = api_key.to_s
      @fetcher = fetcher
    end

    def enabled?
      @api_key.present?
    end

    def fetch
      return [] unless enabled?

      QUERIES.flat_map { |query| search(query) }.uniq { |article| article.url }
    end

    private
      def search(query)
        response = @fetcher.get(
          SEARCH_URL,
          params: {
            q: query,
            lang: "en",
            max: 8,
            in: "title,description",
            apikey: @api_key
          },
          headers: { "X-Api-Key" => @api_key },
          timeout: 20
        )
        return [] unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        Array(data["articles"]).filter_map { |row| to_article(row) }
      rescue JSON::ParserError, SocketError, Timeout::Error, Errno::ECONNREFUSED => error
        Rails.logger.warn("[GnewsAdapter] #{error.class}: #{error.message}")
        []
      end

      def to_article(row)
        url = CanonicalUrl.call(row["url"])
        return if url.blank? || row["title"].blank?

        Article.new(
          url: url,
          title: row["title"].to_s.squish,
          description: row["description"].to_s.squish,
          excerpt: row["content"].to_s.squish.truncate(500),
          source_name: row.dig("source", "name").presence || "GNews",
          image_url: row["image"],
          published_at: parse_time(row["publishedAt"]),
          raw: row
        )
      end

      def parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
  end
end
