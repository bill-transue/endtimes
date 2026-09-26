class BibleLookup
  Resolved = Struct.new(:ref, :book, :chapter, :verse, :text, :found, keyword_init: true)

  BOOK_ALIASES = {
    "gen" => "Genesis",
    "genesis" => "Genesis",
    "ex" => "Exodus",
    "exod" => "Exodus",
    "exodus" => "Exodus",
    "lev" => "Leviticus",
    "leviticus" => "Leviticus",
    "num" => "Numbers",
    "numbers" => "Numbers",
    "deut" => "Deuteronomy",
    "deuteronomy" => "Deuteronomy",
    "josh" => "Joshua",
    "joshua" => "Joshua",
    "judg" => "Judges",
    "judges" => "Judges",
    "ruth" => "Ruth",
    "1sam" => "1 Samuel",
    "1 sam" => "1 Samuel",
    "1 samuel" => "1 Samuel",
    "2sam" => "2 Samuel",
    "2 samuel" => "2 Samuel",
    "1kgs" => "1 Kings",
    "1 kings" => "1 Kings",
    "2kgs" => "2 Kings",
    "2 kings" => "2 Kings",
    "1chr" => "1 Chronicles",
    "1 chronicles" => "1 Chronicles",
    "2chr" => "2 Chronicles",
    "2 chronicles" => "2 Chronicles",
    "ezra" => "Ezra",
    "neh" => "Nehemiah",
    "nehemiah" => "Nehemiah",
    "esth" => "Esther",
    "esther" => "Esther",
    "job" => "Job",
    "ps" => "Psalms",
    "psa" => "Psalms",
    "psalm" => "Psalms",
    "psalms" => "Psalms",
    "prov" => "Proverbs",
    "proverbs" => "Proverbs",
    "eccl" => "Ecclesiastes",
    "ecclesiastes" => "Ecclesiastes",
    "song" => "Song of Solomon",
    "song of solomon" => "Song of Solomon",
    "isa" => "Isaiah",
    "isaiah" => "Isaiah",
    "jer" => "Jeremiah",
    "jeremiah" => "Jeremiah",
    "lam" => "Lamentations",
    "lamentations" => "Lamentations",
    "ezek" => "Ezekiel",
    "ezekiel" => "Ezekiel",
    "dan" => "Daniel",
    "daniel" => "Daniel",
    "hos" => "Hosea",
    "hosea" => "Hosea",
    "joel" => "Joel",
    "amos" => "Amos",
    "obad" => "Obadiah",
    "obadiah" => "Obadiah",
    "jonah" => "Jonah",
    "mic" => "Micah",
    "micah" => "Micah",
    "nah" => "Nahum",
    "nahum" => "Nahum",
    "hab" => "Habakkuk",
    "habakkuk" => "Habakkuk",
    "zeph" => "Zephaniah",
    "zephaniah" => "Zephaniah",
    "hag" => "Haggai",
    "haggai" => "Haggai",
    "zech" => "Zechariah",
    "zechariah" => "Zechariah",
    "mal" => "Malachi",
    "malachi" => "Malachi",
    "mt" => "Matthew",
    "matt" => "Matthew",
    "matthew" => "Matthew",
    "mk" => "Mark",
    "mark" => "Mark",
    "lk" => "Luke",
    "luke" => "Luke",
    "jn" => "John",
    "john" => "John",
    "acts" => "Acts",
    "rom" => "Romans",
    "romans" => "Romans",
    "1cor" => "1 Corinthians",
    "1 cor" => "1 Corinthians",
    "1 corinthians" => "1 Corinthians",
    "2cor" => "2 Corinthians",
    "2 corinthians" => "2 Corinthians",
    "gal" => "Galatians",
    "galatians" => "Galatians",
    "eph" => "Ephesians",
    "ephesians" => "Ephesians",
    "phil" => "Philippians",
    "philippians" => "Philippians",
    "col" => "Colossians",
    "colossians" => "Colossians",
    "1thess" => "1 Thessalonians",
    "1 thessalonians" => "1 Thessalonians",
    "2thess" => "2 Thessalonians",
    "2 thessalonians" => "2 Thessalonians",
    "1tim" => "1 Timothy",
    "1 timothy" => "1 Timothy",
    "2tim" => "2 Timothy",
    "2 timothy" => "2 Timothy",
    "titus" => "Titus",
    "phlm" => "Philemon",
    "philemon" => "Philemon",
    "heb" => "Hebrews",
    "hebrews" => "Hebrews",
    "jas" => "James",
    "james" => "James",
    "1pet" => "1 Peter",
    "1 peter" => "1 Peter",
    "2pet" => "2 Peter",
    "2 peter" => "2 Peter",
    "1jn" => "1 John",
    "1 john" => "1 John",
    "2 john" => "2 John",
    "3 john" => "3 John",
    "jude" => "Jude",
    "rev" => "Revelation",
    "revelation" => "Revelation"
  }.freeze

  REF = /
    \A
    (?<book>\d?\s*[A-Za-z]+(?:\s+[A-Za-z]+)?)
    \.?
    \s+
    (?<chapter>\d+)
    :
    (?<verse>\d+)
    (?:[-–](?<through>\d+))?
    \z
  /x

  def self.resolve(ref)
    new.resolve(ref)
  end

  def self.resolve_many(refs)
    refs.flat_map { |ref| Array(new.expand(ref)) }
  end

  def resolve(ref)
    expand(ref).first || missing(ref.to_s)
  end

  def expand(ref)
    parsed = parse(ref)
    return [ missing(ref.to_s) ] unless parsed

    verses = parsed[:through] ? (parsed[:verse]..parsed[:through]).to_a : [ parsed[:verse] ]
    verses.map { |verse_no| lookup_one("#{parsed[:book]} #{parsed[:chapter]}:#{verse_no}", parsed[:book], parsed[:chapter], verse_no) }
  end

  def parse(ref)
    cleaned = ref.to_s.gsub(/\s+/, " ").strip
    match = REF.match(cleaned)
    return nil unless match

    book = normalize_book(match[:book])
    return nil if book.blank?

    verse = match[:verse].to_i
    through = match[:through]&.to_i
    through = nil if through && through <= verse

    {
      book: book,
      chapter: match[:chapter].to_i,
      verse: verse,
      through: through,
      display: "#{book} #{match[:chapter]}:#{verse}"
    }
  end

  def normalize_book(name)
    key = name.to_s.downcase.gsub(".", "").gsub(/\s+/, " ").strip
    key = key.sub(/\A(\d)\s*/, '\1 ')
    BOOK_ALIASES[key] || BOOK_ALIASES[key.delete(" ")]
  end

  private
    def lookup_one(ref, book, chapter, verse)
      record = BibleVerse.lookup(book, chapter, verse)
      Resolved.new(
        ref: "#{book} #{chapter}:#{verse}",
        book: book,
        chapter: chapter,
        verse: verse,
        text: record&.text,
        found: record.present?
      )
    end

    def missing(ref)
      Resolved.new(ref: ref, book: nil, chapter: nil, verse: nil, text: nil, found: false)
    end
end
