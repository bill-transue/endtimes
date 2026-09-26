class Story < ApplicationRecord
  STATUSES = {
    ingested: 0,
    analyzed: 1,
    published: 2,
    held: 3,
    rejected: 4
  }.freeze

  SOURCE_KINDS = {
    gnews: 0,
    rss: 1,
    demo: 2
  }.freeze

  enum :status, STATUSES
  enum :source_kind, SOURCE_KINDS

  has_one :biblical_analysis, dependent: :destroy

  validates :url, presence: true, uniqueness: true
  validates :title, :source_name, presence: true
  validates :status, :source_kind, presence: true

  scope :feed, -> { published.order(published_at: :desc, id: :desc) }
  scope :admin_queue, -> { order(Arel.sql("CASE status WHEN 1 THEN 0 WHEN 0 THEN 1 WHEN 3 THEN 2 WHEN 2 THEN 3 ELSE 4 END"), published_at: :desc) }
  scope :published_today, -> { published.where(updated_at: Time.current.all_day) }
  scope :awaiting_selection, -> { analyzed.includes(:biblical_analysis) }

  def canonical_url
    url
  end

  def publish!
    update!(status: :published)
  end

  def hold!
    update!(status: :held)
  end

  def reject!
    update!(status: :rejected)
  end

  def excerpt
    description.to_s.squish.truncate(280)
  end
end
