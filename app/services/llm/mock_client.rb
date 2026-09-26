module Llm
  class MockClient < LlmClient
    def mock?
      true
    end

    def analyze_story(input)
      title = input[:title].to_s
      description = input[:description].to_s
      blob = "#{title} #{description}".downcase
      payload = analysis_for(blob, title)

      Result.new(ok: true, payload: payload, raw: payload, model: "mock", error: nil)
    end

    def select_stories(input)
      stories = Array(input[:stories])
      payload = {
        "publish" => stories.first(5).map { |row| row[:id] || row["id"] },
        "hold" => [],
        "reject" => [],
        "rationale" => "Mock selector favors the freshest non-stretch analyses and leaves room for editor override."
      }
      Result.new(ok: true, payload: payload, raw: payload, model: "mock", error: nil)
    end

    private
      def analysis_for(blob, title)
        if blob.match?(/\b(war|wars|missile|missiles|israel|gaza|ukraine|armageddon|apocalypse)\b/)
          {
            "summary" => "Conflict headlines tempt readers to treat the news as a codebook for the last days. Scripture does speak of wars and rumors of wars, but it also forbids date-setting and spectacle. The more honest reading here is a call to lament, to refuse dehumanizing the enemy, and to ask what peacemaking costs us.",
            "themes" => %w[prophecy justice mercy],
            "connections" => [
              { "verse_ref" => "Matthew 24:6", "explanation" => "Jesus names wars as part of a long, grievous history—not a secret timetable.", "stretch" => true },
              { "verse_ref" => "Matthew 5:9", "explanation" => "Blessed are the peacemakers is the moral center, even when prophecy language is in the air.", "stretch" => false }
            ],
            "verse_refs" => [ "Matthew 24:6", "Matthew 5:9", "Psalm 46:1" ],
            "prophecy_relevance" => 0.42,
            "stretch" => true,
            "caveat" => "Naming a war does not license a Revelation overlay. The prophetic link is possible, not proven, and should stay marked as a stretch."
          }
        elsif blob.match?(/\b(refuge|refugee|refugees|famine|aid|hungry|poverty|displaced|asylum|flood)\b/)
          {
            "summary" => "This is a story about neighbors who lack food, shelter, or safety. The Bible's first word is not speculation about the end, but command: do justice, love mercy, and refuse to hide from the poor. Hope here is practical—bread, welcome, and public honesty about who is suffering.",
            "themes" => %w[justice hope mercy],
            "connections" => [
              { "verse_ref" => "Isaiah 58:7", "explanation" => "True worship includes sharing bread and bringing the homeless poor into one's house.", "stretch" => false },
              { "verse_ref" => "Matthew 25:35", "explanation" => "Christ locates himself among the hungry and the stranger.", "stretch" => false }
            ],
            "verse_refs" => [ "Isaiah 58:7", "Matthew 25:35", "Micah 6:8" ],
            "prophecy_relevance" => 0.12,
            "stretch" => false,
            "caveat" => nil
          }
        elsif blob.match?(/\b(corrupt|corruption|bribe|bribes|scandal|abuse|greed|fraud|idol)\b/)
          {
            "summary" => "The report names a public sin: power protecting itself, money posing as wisdom, or the vulnerable being used. Scripture's vocabulary for this is older than any news cycle—idolatry, bribes, and the crushing of the poor. Repentance is corporate as well as personal; exposure is already a kind of mercy if it leads to repair.",
            "themes" => %w[sin justice],
            "connections" => [
              { "verse_ref" => "Amos 5:24", "explanation" => "Justice rolling down like waters is the opposite of a rigged system.", "stretch" => false },
              { "verse_ref" => "Exodus 20:17", "explanation" => "Coveting is not a private quirk; it organizes economies and headlines.", "stretch" => false }
            ],
            "verse_refs" => [ "Amos 5:24", "Exodus 20:17", "Proverbs 14:31" ],
            "prophecy_relevance" => 0.08,
            "stretch" => false,
            "caveat" => nil
          }
        else
          {
            "summary" => "Read as Scripture reads the world, this headline is about ordinary moral weather: fear, pride, relief, or the search for a future. Not every story is a key to Revelation. Some are invitations to tell the truth, keep Sabbath from panic, and practice hope that is sturdier than the news cycle.",
            "themes" => %w[hope wisdom],
            "connections" => [
              { "verse_ref" => "Philippians 4:8", "explanation" => "What is true and just is still worth attending to when the feed is loud.", "stretch" => false },
              { "verse_ref" => "Romans 12:21", "explanation" => "Do not be overcome by evil, but overcome evil with good.", "stretch" => false }
            ],
            "verse_refs" => [ "Philippians 4:8", "Romans 12:21", "Psalm 23:1" ],
            "prophecy_relevance" => 0.05,
            "stretch" => false,
            "caveat" => title.present? ? nil : "Thin source text; analysis is provisional."
          }
        end
      end
  end
end
