module Llm
  class MockClient < LlmClient
    PROPHECY_CLAIMS = /(third temple|red heifer|antichrist|end times|end-times|armageddon|apocalypse|prophecy|prophecies|rapture)/
    ISRAEL = /\b(israel|israeli|israelis|jerusalem|west bank|gaza|temple mount)\b/
    PERSECUTION = /(persecut|martyr|blasphemy|church (attack|bomb|burn)|(attack|bomb|burn)\w* (a |the )?church|(kill|abduct|attack|arrest)\w* (\w+ )?christians?\b|christians? (\w+ ){0,2}(killed|abducted|attacked|arrested))/
    BIRTH_PAINS = /\b(famine|plague|pestilence|epidemic|pandemic|earthquake|earthquakes)\b/
    WAR = /\b(war|wars|missile|missiles|ukraine|ceasefire|invasion|airstrike|airstrikes|great power)\b/

    def mock?
      true
    end

    def analyze_story(input)
      title = input[:title].to_s
      description = input[:description].to_s
      blob = "#{title} #{description}".downcase
      focus = (input[:focus].presence || EditorialSetting.current.focus).to_s
      payload = focus == "broad" ? broad_analysis_for(blob, title) : leaning_analysis_for(blob, title)

      Result.new(ok: true, payload: payload, raw: payload, model: "mock", error: nil)
    end

    def select_stories(input)
      stories = Array(input[:stories])
      cap = input[:cap].to_i
      payload = {
        "publish" => stories.first([ cap, 5 ].min).map { |row| row[:id] || row["id"] },
        "hold" => stories.drop([ cap, 5 ].min).map { |row| row[:id] || row["id"] },
        "reject" => [],
        "rationale" => "Mock selector publishes the top-ranked analyses and leaves the rest held for editors."
      }
      Result.new(ok: true, payload: payload, raw: payload, model: "mock", error: nil)
    end

    private
      # End times leaning and Mix: look for genuine last-days connections, but keep thin links marked stretch.
      def leaning_analysis_for(blob, title)
        if blob.match?(PROPHECY_CLAIMS)
          {
            "summary" => "This story is about a prophetic claim, not proof of one. Jesus told his disciples to expect such claims and to test them rather than chase them. The faithful response is attention without alarm: neither mocking the question of the end nor letting a headline set the date.",
            "themes" => %w[prophecy wisdom],
            "connections" => [
              { "verse_ref" => "Matthew 24:4", "explanation" => "Jesus' first word about the end is a warning against being led astray.", "stretch" => false },
              { "verse_ref" => "Matthew 24:36", "explanation" => "No one knows the day or the hour, so no news item can set it.", "stretch" => false }
            ],
            "verse_refs" => [ "Matthew 24:4", "Matthew 24:36", "1 John 4:1" ],
            "prophecy_relevance" => 0.7,
            "stretch" => false,
            "caveat" => "We analyze the claim; we do not endorse it. Scripture does not say this event fulfills prophecy."
          }
        elsif blob.match?(ISRAEL)
          {
            "summary" => "Jerusalem and the land sit near the center of the prophets' hope and Jesus' warnings, so news from here deserves careful reading. The honest response is prayer for peace, grief for every life lost, and refusal to treat any people as props in a timeline. Scripture frames Jerusalem's future, but it does not hand us a schedule for this week's events.",
            "themes" => %w[prophecy nations justice],
            "connections" => [
              { "verse_ref" => "Psalms 122:6", "explanation" => "Praying for the peace of Jerusalem is a command, not a forecast.", "stretch" => false },
              { "verse_ref" => "Luke 21:24", "explanation" => "Jesus spoke of Jerusalem among the nations; tying that to this specific report is uncertain.", "stretch" => true },
              { "verse_ref" => "Zechariah 12:3", "explanation" => "The prophets picture the nations gathering around Jerusalem; the link to this story is suggestive, not proven.", "stretch" => true }
            ],
            "verse_refs" => [ "Psalms 122:6", "Luke 21:24", "Zechariah 12:3" ],
            "prophecy_relevance" => 0.62,
            "stretch" => false,
            "caveat" => "Jerusalem is central to biblical prophecy; this headline is not a fulfillment marker."
          }
        elsif blob.match?(PERSECUTION)
          {
            "summary" => "Believers are suffering for the name of Christ, which Jesus said would mark the age before his return. The first response is not speculation but solidarity: remember those in chains as if bound with them, pray, and press for their protection. Their endurance is itself a witness.",
            "themes" => %w[prophecy mercy justice],
            "connections" => [
              { "verse_ref" => "Matthew 24:9", "explanation" => "Jesus warned that his followers would be handed over and killed for his name.", "stretch" => false },
              { "verse_ref" => "Hebrews 13:3", "explanation" => "The church is told to remember prisoners and the mistreated as members of one body.", "stretch" => false }
            ],
            "verse_refs" => [ "Matthew 24:9", "Hebrews 13:3", "Matthew 24:13" ],
            "prophecy_relevance" => 0.58,
            "stretch" => false,
            "caveat" => nil
          }
        elsif blob.match?(BIRTH_PAINS)
          {
            "summary" => "Famine, plague, and earthquake belong to the 'birth pains' Jesus described, but he also said such things are not yet the end. The first call is mercy to people in need: bread, medicine, shelter. Watchfulness and compassion belong together here.",
            "themes" => %w[prophecy mercy justice],
            "connections" => [
              { "verse_ref" => "Luke 21:11", "explanation" => "Jesus named earthquakes, famines, and plagues among the signs of the age.", "stretch" => false },
              { "verse_ref" => "Matthew 24:8", "explanation" => "He called them the beginning of birth pains, not a countdown.", "stretch" => false },
              { "verse_ref" => "Isaiah 58:7", "explanation" => "True worship shares bread with the hungry.", "stretch" => false }
            ],
            "verse_refs" => [ "Luke 21:11", "Matthew 24:8", "Isaiah 58:7" ],
            "prophecy_relevance" => 0.48,
            "stretch" => false,
            "caveat" => "Disasters fit the pattern Jesus described; no single disaster is a timetable."
          }
        elsif blob.match?(WAR)
          {
            "summary" => "Nations rising against nations is part of the pattern Jesus described, and wars do belong in a last-days reading. But he paired the warning with 'the end is not yet,' and the more honest response to this specific conflict is lament, prayer for peacemakers, and refusal to dehumanize the enemy.",
            "themes" => %w[nations prophecy mercy],
            "connections" => [
              { "verse_ref" => "Matthew 24:6", "explanation" => "Wars and rumors of wars are expected, but they are not a timetable.", "stretch" => true },
              { "verse_ref" => "Matthew 5:9", "explanation" => "Blessed are the peacemakers is the moral center, even when prophecy language is in the air.", "stretch" => false }
            ],
            "verse_refs" => [ "Matthew 24:6", "Matthew 24:7", "Matthew 5:9" ],
            "prophecy_relevance" => 0.45,
            "stretch" => true,
            "caveat" => "Naming a war does not license a Revelation overlay. The prophetic link to this conflict is possible, not proven, and stays marked as a stretch."
          }
        else
          broad_analysis_for(blob, title)
        end
      end

      def broad_analysis_for(blob, title)
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
