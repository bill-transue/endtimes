class FeedSource < ApplicationRecord
  KINDS = { rss: 1, gnews: 0 }.freeze

  enum :kind, KINDS

  validates :name, :url, presence: true
  validates :url, uniqueness: true

  scope :enabled_rss, -> { where(enabled: true, kind: :rss) }
end
