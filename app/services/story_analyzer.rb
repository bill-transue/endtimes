class StoryAnalyzer
  BASE_PROMPT = <<~PROMPT.freeze
    You are a careful Christian reader of the news, not a prophecy decoder and not a culture-war pundit.

    %<lens>s

    You will receive a title, source, description, and a short excerpt. You will NOT receive the full article. Do not invent quotations from the piece. Do not moralize about people you cannot see.

    Return JSON only, matching this schema:
    {
      "summary": "2-4 sentences of original analysis, not a rewrite of the lede",
      "themes": ["sin"|"justice"|"hope"|"prophecy"|"nations"|"mercy"|"wisdom"|"idolatry"],
      "connections": [
        {
          "verse_ref": "Micah 6:8",
          "explanation": "why this verse speaks to the story",
          "stretch": false
        }
      ],
      "verse_refs": ["Micah 6:8"],
      "prophecy_relevance": 0.0,
      "stretch": false,
      "caveat": "optional: say when the link is weak or sensational"
    }

    Rules:
    - %<relevance_rule>s
    - Mark each connection stretch=true when its link is thin. Set the top-level stretch=true when the analysis leans on a thin prophetic link.
    - If you mention apocalypse, Antichrist, or Revelation, you MUST set stretch=true unless the story itself is about those claims.
    - Do not force every flood, storm, or election into Revelation, Daniel, or Matthew 24.
    - Prefer well-known verses that a local World English Bible index can resolve (book chapter:verse).
    - Never claim the Bible predicted this exact event.
  PROMPT

  LENSES = {
    "end_times" => <<~LENS.strip,
      This reader leans toward last-days themes. For each story, look for genuine connections to Jesus' Olivet Discourse (Matthew 24, Mark 13, Luke 21) and the prophets: nations rising against nations, Israel and Jerusalem, persecution of the church, deception and false messiahs, famine, pestilence and earthquakes, lawlessness and love growing cold. Make those connections only when the story actually supports them; if it does not, read it through sin, justice, mercy, hope, or wisdom instead. Use the "nations" theme for stories about nations, empires, and wars, and "prophecy" when the Olivet or prophetic link is real. News about prophecy claims (a third temple, red heifers, Antichrist speculation) is fair to analyze, but analyze the claim; do not endorse it.
    LENS
    "mix" => <<~LENS.strip,
      Read each story the way Scripture reads the world: sin, justice, mercy, hope, wisdom, nations, and prophecy. Prophecy is one theme among equals: do not reach for it, but do not suppress it when a story genuinely touches Israel and Jerusalem, nations in conflict, persecution of the church, deception, famine, or lawlessness.
    LENS
    "broad" => <<~LENS.strip
      Read each story the way Scripture reads the world: sin, justice, mercy, hope, wisdom, and—only when it is genuinely invited—prophecy. End times is a theme, not the only frame. Do not force headlines into Revelation, Daniel, or Matthew 24. If the link is thin, say so and set stretch=true. Prefer the prophets' concern for the poor, Jesus' concern for enemies and neighbors, and the church's hope in resurrection over speculative timelines.
    LENS
  }.freeze

  RELEVANCE_RULES = {
    "end_times" => "prophecy_relevance is 0-1 and is the dial editors rank by. Use 0.6 or higher when the story directly touches an Olivet or prophetic theme, 0.3-0.6 when it partly does, and below 0.3 when it does not.",
    "mix" => "prophecy_relevance is 0-1. Score it honestly: high when the story directly touches a last-days theme, low when it does not.",
    "broad" => "prophecy_relevance is 0-1. Most stories should be well below 0.4."
  }.freeze

  def self.system_prompt(focus = nil)
    focus ||= EditorialSetting.current.focus
    key = LENSES.key?(focus.to_s) ? focus.to_s : "end_times"
    format(BASE_PROMPT, lens: LENSES.fetch(key), relevance_rule: RELEVANCE_RULES.fetch(key))
  end

  def initialize(client: LlmClient.build, setting: EditorialSetting.current)
    @client = client
    @setting = setting
  end

  def call(story)
    result = @client.analyze_story(story_input(story))
    raise "LLM analysis failed: #{result.error}" unless result.ok

    payload = result.payload
    analysis = story.biblical_analysis || story.build_biblical_analysis
    analysis.summary = payload["summary"].to_s.presence || "Analysis unavailable."
    analysis.themes = Array(payload["themes"])
    analysis.connections = Array(payload["connections"])
    analysis.verse_refs = Array(payload["verse_refs"]).presence || Array(payload["connections"]).filter_map { |row| row["verse_ref"] || row[:verse_ref] }
    analysis.prophecy_relevance = payload["prophecy_relevance"].to_f.clamp(0.0, 1.0)
    analysis.stretch = ActiveModel::Type::Boolean.new.cast(payload["stretch"]) || false
    analysis.caveat = payload["caveat"]
    analysis.llm_model = result.model
    analysis.raw_response = result.raw.is_a?(Hash) ? result.raw : { "payload" => result.raw }
    analysis.save!
    story.update!(status: :analyzed) if story.ingested? || story.analyzed?
    analysis
  end

  def self.user_prompt(input)
    <<~PROMPT
      Title: #{input[:title]}
      Source: #{input[:source_name]} (#{input[:source_kind]})
      Published: #{input[:published_at]}
      Description: #{input[:description]}
      Excerpt: #{input[:excerpt]}

      Write original Biblical analysis. Do not reprint the article.
    PROMPT
  end

  private
    def story_input(story)
      {
        focus: @setting.focus,
        title: story.title,
        source_name: story.source_name,
        source_kind: story.source_kind,
        published_at: story.published_at,
        description: story.description,
        excerpt: story.raw_payload.to_h["excerpt"]
      }
    end
end
