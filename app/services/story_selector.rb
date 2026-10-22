class StorySelector
  BASE_PROMPT = <<~PROMPT.freeze
    You help editors choose which Biblically analyzed news stories to publish on a public reader.

    %<guidance>s

    Never publish an analysis that claims the Bible predicted this exact event.

    Return JSON:
    {
      "publish": [story_id integers],
      "hold": [story_id integers],
      "reject": [story_id integers],
      "rationale": "short editor note"
    }

    Every submitted id must appear in exactly one list. Honor the daily publish cap given in the user prompt.
  PROMPT

  GUIDANCE = {
    "end_times" => <<~TEXT.strip,
      This reader leans toward last-days themes. Prefer genuine last-days connections (Israel and Jerusalem, nations in conflict, persecution of the church, famine, pestilence and earthquakes, deception, lawlessness) over a generic hope or wisdom reading when both exist. Rank by prophecy relevance when stretch=false, then connection quality, freshness, and non-sensational sources. Put stories with stretch=true in hold, not publish and not reject, so editors can review them.
    TEXT
    "mix" => <<~TEXT.strip,
      Prefer genuine connection quality, theme diversity, freshness, and non-sensational sources across justice, mercy, hope, sin, and prophecy. Do not let prophecy be drowned out: publish at least the prophecy floor given in the user prompt from stories with a prophecy or nations theme, stretch=false, and prophecy at or above the minimum, when any exist. Do not reward stretch prophecy takes.
    TEXT
    "broad" => <<~TEXT.strip
      Prefer genuine connection quality, theme diversity, freshness, and non-sensational sources. Do not reward stretch prophecy takes. A justice or hope story with a clear verse is better than a war story forced into Revelation.
    TEXT
  }.freeze

  TRUSTED = /reuters|associated press|\bap\b|bbc|npr|religion news|christianity today|the guardian|al jazeera/i
  PROPHECY_THEMES = %w[prophecy nations].freeze
  MIX_DAILY_PROPHECY_FLOOR = 2

  def self.system_prompt(focus = nil)
    focus ||= EditorialSetting.current.focus
    format(BASE_PROMPT, guidance: GUIDANCE.fetch(focus.to_s, GUIDANCE.fetch("end_times")))
  end

  def initialize(client: LlmClient.build, setting: EditorialSetting.current, cap: setting.effective_daily_publish_cap)
    @client = client
    @setting = setting
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
    decisions = enforce_focus(decisions, ranked, remaining)

    apply(decisions, stories)
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
    header = [ "Daily publish remaining: #{cap}" ]
    header << "Minimum prophecy relevance: #{input[:min_prophecy_relevance]}" if input[:min_prophecy_relevance]
    header << "Prophecy floor still needed today: #{input[:prophecy_floor]}" if input[:prophecy_floor]
    header.join("\n") + "\n\n" + rows.join("\n")
  end

  def heuristic_score(story)
    analysis = story.biblical_analysis
    return 0.0 unless analysis

    score = @setting.end_times? ? end_times_score(analysis) : broad_score(analysis)
    score += 0.15 if story.source_name.to_s.match?(TRUSTED)
    hours = [ ((Time.current - (story.published_at || story.created_at)) / 1.hour), 0 ].max
    score += 0.15 * Math.exp(-hours / 48.0)
    score += 0.1 if analysis.looked_up_verses.any?(&:found)
    score
  end

  def prophecy_relevant?(analysis)
    return false unless analysis

    analysis.theme_list.intersect?(PROPHECY_THEMES) && analysis.prophecy_relevance.to_f >= @setting.min_prophecy_relevance
  end

  private
    def broad_score(analysis)
      score = 0.35
      score += 0.25 unless analysis.stretch?
      score += 0.15 if analysis.theme_list.intersect?(%w[justice hope mercy sin wisdom])
      score -= 0.2 if analysis.stretch? && analysis.prophecy_relevance.to_f > 0.5
      score
    end

    def end_times_score(analysis)
      score = 0.35
      if analysis.stretch?
        score += 0.05 if prophecy_relevant?(analysis)
      else
        score += 0.2
        score += 0.35 * analysis.prophecy_relevance.to_f
        score += 0.25 if prophecy_relevant?(analysis)
      end
      score
    end

    def heuristic_decisions(ranked, remaining)
      publishable = @setting.end_times? ? ranked.reject { |story| story.biblical_analysis&.stretch? } : ranked
      publish = publishable.first(remaining).map(&:id)
      hold = ranked.map(&:id) - publish
      { "publish" => publish, "hold" => hold, "reject" => [], "rationale" => "heuristic (#{@setting.focus})" }
    end

    def llm_decisions(ranked, remaining)
      input = {
        focus: @setting.focus,
        cap: remaining,
        min_prophecy_relevance: @setting.min_prophecy_relevance,
        prophecy_floor: (prophecy_floor_needed if @setting.mix?),
        stories: ranked.map { |story| serialize(story) }
      }
      result = @client.select_stories(input)
      return heuristic_decisions(ranked, remaining) unless result.ok

      payload = result.payload
      publish = Array(payload["publish"]).map(&:to_i).first(remaining)
      hold = Array(payload["hold"]).map(&:to_i) - publish
      reject = Array(payload["reject"]).map(&:to_i) - publish - hold
      { "publish" => publish, "hold" => hold, "reject" => reject, "rationale" => payload["rationale"] }
    end

    def enforce_focus(decisions, ranked, remaining)
      if @setting.end_times?
        hold_stretch(decisions, ranked, remaining)
      elsif @setting.mix?
        enforce_prophecy_floor(decisions, ranked, remaining)
      else
        decisions
      end
    end

    # Stretch takes are held for editors, and the freed slots go to the best non-stretch held stories.
    def hold_stretch(decisions, ranked, remaining)
      stretch_ids = ranked.select { |story| story.biblical_analysis&.stretch? }.map(&:id)
      demoted = decisions["publish"] & stretch_ids
      publish = decisions["publish"] - stretch_ids
      hold = decisions["hold"] | demoted
      backfill = ranked.map(&:id).select { |id| hold.include?(id) && !stretch_ids.include?(id) }
      backfill.first([ [ demoted.size, remaining - publish.size ].min, 0 ].max).each do |id|
        publish << id
        hold.delete(id)
      end
      decisions.merge("publish" => publish, "hold" => hold)
    end

    def enforce_prophecy_floor(decisions, ranked, remaining)
      eligible = ranked.select { |story| floor_eligible?(story.biblical_analysis) }.map(&:id)
      publish = decisions["publish"].dup
      hold = decisions["hold"].dup
      need = prophecy_floor_needed - (publish & eligible).size
      rank = ranked.each_with_index.to_h { |story, index| [ story.id, index ] }

      (eligible - publish - decisions["reject"]).first([ need, 0 ].max).each do |id|
        if publish.size >= remaining
          victim = publish.reject { |pid| eligible.include?(pid) }.max_by { |pid| rank.fetch(pid, ranked.size) }
          break unless victim

          publish.delete(victim)
          hold << victim
        end
        break if publish.size >= remaining

        publish << id
        hold.delete(id)
      end
      decisions.merge("publish" => publish, "hold" => hold)
    end

    def prophecy_floor_needed
      floor = [ MIX_DAILY_PROPHECY_FLOOR, @cap ].min
      already = Story.published_today.includes(:biblical_analysis).count { |story| floor_eligible?(story.biblical_analysis) }
      [ floor - already, 0 ].max
    end

    def floor_eligible?(analysis)
      prophecy_relevant?(analysis) && !analysis.stretch?
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

    def apply(decisions, stories)
      allowed = Story.where(id: stories.map(&:id), status: Story::SELECTABLE_STATUSES).pluck(:id)
      Story.where(id: Array(decisions["publish"]).map(&:to_i) & allowed).find_each(&:publish!)
      Story.where(id: Array(decisions["hold"]).map(&:to_i) & allowed).find_each(&:hold!)
      Story.where(id: Array(decisions["reject"]).map(&:to_i) & allowed).find_each(&:reject!)
    end
end
