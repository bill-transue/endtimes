# Demo published stories so the reader works when crawl/LLM keys are absent.
# Original URLs point at publisher section pages, not republished bodies.

DEMO = [
  {
    url: "https://www.bbc.com/news/world",
    title: "Aid groups warn famine is spreading faster than the trucks can move",
    description: "Humanitarian agencies say displacement and blocked corridors are leaving families without staple food.",
    source_name: "BBC World",
    keywords: "famine refugees aid hungry"
  },
  {
    url: "https://www.theguardian.com/world",
    title: "Prosecutors charge a cabinet favorite with years of hidden bribes",
    description: "Court filings describe contracts steered toward relatives in exchange for cash and apartments.",
    source_name: "The Guardian",
    keywords: "corruption bribe scandal greed"
  },
  {
    url: "https://religionnews.com/",
    title: "A small church opens its hall to flood evacuees without a sermon attached",
    description: "Volunteers in a river town offered cots, soup, and a dry floor after overnight water rose through the streets.",
    source_name: "Religion News Service",
    keywords: "flood aid hope welcome"
  },
  {
    url: "https://www.aljazeera.com/news/",
    title: "Overnight strikes jolt a ceasefire and revive talk of a wider war",
    description: "Analysts argue over whether the latest barrage is a bargaining chip or the start of a longer campaign.",
    source_name: "Al Jazeera",
    keywords: "war missile ceasefire"
  }
].freeze

DEMO.each do |row|
  story = Story.find_or_initialize_by(url: row[:url])
  story.assign_attributes(
    title: row[:title],
    description: row[:description],
    source_name: row[:source_name],
    source_kind: :demo,
    published_at: story.published_at || 6.hours.ago,
    raw_payload: { "excerpt" => row[:description], "demo" => true, "keywords" => row[:keywords] }
  )
  story.status = :ingested if story.new_record?
  story.save!

  next if story.biblical_analysis.present?

  client = Llm::MockClient.new
  result = client.analyze_story(title: row[:title], description: "#{row[:description]} #{row[:keywords]}")
  payload = result.payload
  story.create_biblical_analysis!(
    summary: payload["summary"],
    themes: payload["themes"],
    connections: payload["connections"],
    verse_refs: payload["verse_refs"],
    prophecy_relevance: payload["prophecy_relevance"],
    stretch: payload["stretch"],
    caveat: payload["caveat"],
    llm_model: "mock",
    raw_response: payload
  )
  story.publish!
end

held = Story.find_or_initialize_by(url: "https://www.npr.org/sections/news/")
held.assign_attributes(
  title: "A celebrity pastor's book tour collides with unpaid laborers at the printer",
  description: "Warehouse staff say overtime vanished while the memoir about humility shipped in the tens of thousands.",
  source_name: "NPR",
  source_kind: :demo,
  status: :held,
  published_at: 2.days.ago,
  raw_payload: { "excerpt" => "unpaid laborers memoir humility", "demo" => true }
)
held.save!
unless held.biblical_analysis
  result = Llm::MockClient.new.analyze_story(title: held.title, description: held.description)
  held.create_biblical_analysis!(
    summary: result.payload["summary"],
    themes: result.payload["themes"],
    connections: result.payload["connections"],
    verse_refs: result.payload["verse_refs"],
    prophecy_relevance: result.payload["prophecy_relevance"],
    stretch: result.payload["stretch"],
    caveat: result.payload["caveat"],
    llm_model: "mock",
    raw_response: result.payload
  )
end
