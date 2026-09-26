require "test_helper"

class BibleLookupTest < ActiveSupport::TestCase
  setup do
    seed_verse!(book: "Psalms", chapter: 23, verse: 1, text: "Yahweh is my shepherd; I shall lack nothing.")
    seed_verse!(book: "Micah", chapter: 6, verse: 8, text: "He has shown you, O man, what is good.")
  end

  test "resolves aliases and missing refs degrade" do
    found = BibleLookup.resolve("Psalm 23:1")
    assert found.found
    assert_equal "Yahweh is my shepherd; I shall lack nothing.", found.text

    missing = BibleLookup.resolve("Obadiah 1:1")
    assert_not missing.found
    assert_nil missing.text
    assert_equal "Obadiah 1:1", missing.ref

    unparsed = BibleLookup.resolve("not a verse")
    assert_not unparsed.found
  end

  test "expands ranges" do
    seed_verse!(book: "Psalms", chapter: 23, verse: 2, text: "He makes me lie down.")
    refs = BibleLookup.resolve_many([ "Psalm 23:1-2" ])
    assert_equal 2, refs.size
    assert refs.all?(&:found)
  end
end
