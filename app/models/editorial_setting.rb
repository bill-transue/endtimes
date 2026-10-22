class EditorialSetting < ApplicationRecord
  FOCUSES = { end_times: 0, mix: 1, broad: 2 }.freeze

  FOCUS_LABELS = {
    "end_times" => "End times leaning",
    "mix" => "Mix",
    "broad" => "Broad biblical"
  }.freeze

  FOCUS_DESCRIPTIONS = {
    "end_times" => "Fetch and publish stories that touch last-days themes: Israel and Jerusalem, nations in conflict, persecution, famine, deception, lawlessness. Thin prophecy links stay marked stretch and are held for review.",
    "mix" => "Broad Biblical lens (justice, mercy, hope, sin), with a daily floor of prophecy-tagged stories so prophecy is not drowned out.",
    "broad" => "Original behavior: justice and hope first, prophecy only when clearly invited."
  }.freeze

  END_TIMES_GNEWS_QUERIES = [
    'Israel OR Jerusalem OR "West Bank" OR Gaza',
    'persecution OR "killed Christians" OR "church attack"',
    'famine OR plague OR earthquake OR "red heifer"',
    '"third temple" OR Antichrist OR "end times" OR prophecy',
    'war OR ceasefire OR "great power"'
  ].freeze

  BROAD_GNEWS_QUERIES = [
    'justice OR refugees OR famine OR "human rights"',
    "church OR Christianity OR persecution OR clergy",
    "war OR ceasefire OR peace OR genocide",
    "corruption OR poverty OR greed OR scandal"
  ].freeze

  DEFAULT_DAILY_PUBLISH_CAP = 10

  enum :focus, FOCUSES, validate: true

  validates :min_prophecy_relevance, numericality: { in: 0.0..1.0 }
  validates :daily_publish_cap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :normalize_gnews_queries

  def self.current
    first || create!(gnews_queries: END_TIMES_GNEWS_QUERIES)
  rescue ActiveRecord::RecordNotUnique
    first
  end

  def self.default_daily_publish_cap
    ENV.fetch("DAILY_PUBLISH_CAP", DEFAULT_DAILY_PUBLISH_CAP).to_i
  end

  def focus_label
    FOCUS_LABELS.fetch(focus)
  end

  def effective_daily_publish_cap
    daily_publish_cap || self.class.default_daily_publish_cap
  end

  def query_list
    queries = Array(gnews_queries).map(&:to_s).map(&:strip).reject(&:blank?)
    queries.presence || (broad? ? BROAD_GNEWS_QUERIES : END_TIMES_GNEWS_QUERIES)
  end

  def gnews_queries_text
    Array(gnews_queries).join("\n")
  end

  def gnews_queries_text=(text)
    self.gnews_queries = text.to_s.lines
  end

  private
    def normalize_gnews_queries
      self.gnews_queries = Array(gnews_queries).map { |query| query.to_s.squish }.reject(&:blank?).uniq
    end
end
