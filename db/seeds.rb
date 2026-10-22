require "json"

verses_path = Rails.root.join("db/data/web_verses.json")
JSON.parse(verses_path.read).each do |row|
  verse = BibleVerse.find_or_initialize_by(book: row["book"], chapter: row["chapter"], verse: row["verse"])
  verse.text = row["text"]
  verse.save!
end

# Creates the editorial setting with end-times queries on first run only; admin edits survive re-seeding.
EditorialSetting.current

# New feeds start enabled; `enabled` is never changed for an existing row, so admin toggles survive re-seeding.
[
  { name: "BBC World", url: "https://feeds.bbci.co.uk/news/world/rss.xml", kind: :rss },
  { name: "The Guardian World", url: "https://www.theguardian.com/world/rss", kind: :rss },
  { name: "Al Jazeera", url: "https://www.aljazeera.com/xml/rss/all.xml", kind: :rss },
  { name: "Religion News Service", url: "https://religionnews.com/feed/", kind: :rss },
  { name: "Christianity Today", url: "https://www.christianitytoday.com/feed/", kind: :rss },
  { name: "NPR News", url: "https://feeds.npr.org/1001/rss.xml", kind: :rss },
  { name: "Times of Israel", url: "https://www.timesofisrael.com/feed/", kind: :rss },
  { name: "Jerusalem Post", url: "https://www.jpost.com/rss/rssfeedsfrontpage.aspx", kind: :rss },
  { name: "International Christian Concern", url: "https://www.persecution.org/feed/", kind: :rss },
  { name: "Morning Star News", url: "https://morningstarnews.org/feed/", kind: :rss }
].each do |attrs|
  source = FeedSource.find_or_initialize_by(url: attrs[:url])
  source.name = attrs[:name]
  source.kind = attrs[:kind]
  source.enabled = true if source.new_record?
  source.save!
end

if Story.published.none?
  load Rails.root.join("db/seeds/demo_stories.rb")
end

puts "Seeded #{BibleVerse.count} WEB verses, #{FeedSource.count} feed sources, #{Story.published.count} published stories; editorial focus is #{EditorialSetting.current.focus_label}."
