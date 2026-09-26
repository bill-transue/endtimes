class BibleVerse < ApplicationRecord
  validates :book, :text, presence: true
  validates :chapter, :verse, presence: true, numericality: { greater_than: 0 }
  validates :verse, uniqueness: { scope: [ :book, :chapter ] }

  def citation
    "#{book} #{chapter}:#{verse}"
  end

  def self.lookup(book, chapter, verse)
    find_by(book: book, chapter: chapter, verse: verse)
  end
end
