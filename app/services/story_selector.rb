class StorySelector
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You help editors choose which Biblically analyzed news stories to publish on a public reader.

    Prefer genuine connection quality, theme diversity, freshness, and non-sensational sources. Do not reward stretch prophecy takes. A justice or hope story with a clear verse is better than a war story forced into Revelation.

    Return JSON:
    {
      "publish": [story_id integers],
      "hold": [story_id integers],
      "reject": [story_id integers],
      "rationale": "short editor note"
    }

    Every submitted id must appear in exactly one list. Honor the daily publish cap given in the user prompt.
  PROMPT

  TRUSTED = /reuters|associated press|\bap\b|bbc|npr|religion news|christianity today|the guardian|al jazeera/i

  def initialize(client: LlmClient.build, cap: ENV.fetch("DAILY_PUBLISH_CAP", "10").to_i)
    @client = client
    @cap = cap
  end

  def call(stories = Story.awaiting_selection.to_a)
    remaining = [ @cap - Story.published_today.count, 0 ].max
    ranked = stories.sort_by { |story| -heuristic_score(story) }

    decisions = if @client.mock?
      heuristic_decisions(ranked, remaining)
    else
      llm_decisions(ranked, remaining)
    end

    apply(decisions)
    decisions
  end

  def self.user_prompt(input)
    cap = input[:cap]
    rows = Array(input[:stories]).map do |row|
      <<~ROW
        id=#{row[:id]} title=#{row[:title]} source=#{row[:source_name]} published=#{row[:published_at]}
        themes=#{Array(row[:themes]).join(',')} stretch=#{row[:stretch]} prophecy=#{row[:prophecy_relevance]}
        summary=#{row[:summary]}
      ROW
    end
    "Daily publish remaining: #{cap}\n\n" + rows.join("\n")
  end

  def heuristic_score(story)
    analysis = story.biblical_analysis
    return 0.0 unless analysis

    score = 0.35
    score += 0.25 unless analysis.stretch?
    score += 0.15 if analysis.theme_list.intersect?(%w[justice hope mercy sin wisdom])
    score -= 0.2 if analysis.stretch? && analysis.prophecy_relevance.to_f > 0.5
    score += 0.15 if story.source_name.to_s.match?(TRUSTED)
    hours = [ ((Time.current - (story.published_at || story.created_at)) / 1.hour), 0 ].max
    score += 0.15 * Math.exp(-hours / 48.0)
    score += 0.1 if analysis.looked_up_verses.any?(&:found)
    score
  end

  private
    def heuristic_decisions(ranked, remaining)
      publish = ranked.first(remaining).map(&:id)
      hold = ranked.drop(remaining).select { |story| story.biblical_analysis&.stretch? }.map(&:id)
      reject = []
      rest = ranked.map(&:id) - publish - hold
      hold.concat(rest)
      { "publish" => publish, "hold" => hold, "reject" => reject, "rationale" => "heuristic" }
    end

    def llm_decisions(ranked, remaining)
      input = {
        cap: remaining,
        stories: ranked.map { |story| serialize(story) }
      }
      result = @client.select_stories(input)
      return heuristic_decisions(ranked, remaining) unless result.ok

      payload = result.payload
      publish = Array(payload["publish"]).map(&:to_i).first(remaining)
      hold = Array(payload["hold"]).map(&:to_i)
      reject = Array(payload["reject"]).map(&:to_i)
      { "publish" => publish, "hold" => hold, "reject" => reject, "rationale" => payload["rationale"] }
    end

    def serialize(story)
      analysis = story.biblical_analysis
      {
        id: story.id,
        title: story.title,
        source_name: story.source_name,
        published_at: story.published_at,
        themes: analysis&.theme_list,
        stretch: analysis&.stretch,
        prophecy_relevance: analysis&.prophecy_relevance,
        summary: analysis&.summary
      }
    end

    def apply(decisions)
      allowed = Story.awaiting_selection.pluck(:id)
      Story.where(id: Array(decisions["publish"]).map(&:to_i) & allowed).find_each(&:publish!)
      Story.where(id: Array(decisions["hold"]).map(&:to_i) & allowed).find_each(&:hold!)
      Story.where(id: Array(decisions["reject"]).map(&:to_i) & allowed).find_each(&:reject!)
    end
end
