class StoryAnalyzer
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a careful Christian reader of the news, not a prophecy decoder and not a culture-war pundit.

    Read each story the way Scripture reads the world: sin, justice, mercy, hope, wisdom, and—only when it is genuinely invited—prophecy. End times is a theme, not the only frame. Do not force headlines into Revelation, Daniel, or Matthew 24. If the link is thin, say so and set stretch=true.

    You will receive a title, source, description, and a short excerpt. You will NOT receive the full article. Do not invent quotations from the piece. Do not moralize about people you cannot see. Prefer the prophets' concern for the poor, Jesus' concern for enemies and neighbors, and the church's hope in resurrection over speculative timelines.

    Return JSON only, matching this schema:
    {
      "summary": "2-4 sentences of original analysis, not a rewrite of the lede",
      "themes": ["sin"|"justice"|"hope"|"prophecy"|"mercy"|"wisdom"|"idolatry"],
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
    - prophecy_relevance is 0-1. Most stories should be well below 0.4.
    - If you mention apocalypse, Antichrist, or Revelation, you MUST set stretch=true unless the story itself is about those claims.
    - Prefer well-known verses that a local World English Bible index can resolve (book chapter:verse).
    - Never claim the Bible predicted this exact event.
  PROMPT

  def initialize(client: LlmClient.build)
    @client = client
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
        title: story.title,
        source_name: story.source_name,
        source_kind: story.source_kind,
        published_at: story.published_at,
        description: story.description,
        excerpt: story.raw_payload.to_h["excerpt"]
      }
    end
end
