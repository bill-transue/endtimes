class BiblicalAnalysis < ApplicationRecord
  belongs_to :story

  validates :summary, presence: true
  validates :prophecy_relevance, numericality: { in: 0.0..1.0 }

  def theme_list
    Array(themes).map { |theme| theme.to_s.downcase }.uniq
  end

  def connection_list
    Array(connections).map { |row| row.is_a?(Hash) ? row.with_indifferent_access : {} }
  end

  def verse_ref_list
    Array(verse_refs).map(&:to_s).reject(&:blank?).uniq
  end

  def looked_up_verses
    BibleLookup.resolve_many(verse_ref_list)
  end
end
