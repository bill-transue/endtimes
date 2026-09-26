# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_26_184354) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bible_verses", force: :cascade do |t|
    t.string "book", null: false
    t.integer "chapter", null: false
    t.integer "verse", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book", "chapter", "verse"], name: "index_bible_verses_on_book_and_chapter_and_verse", unique: true
  end

  create_table "biblical_analyses", force: :cascade do |t|
    t.bigint "story_id", null: false
    t.text "summary", null: false
    t.jsonb "themes", default: [], null: false
    t.jsonb "connections", default: [], null: false
    t.jsonb "verse_refs", default: [], null: false
    t.float "prophecy_relevance", default: 0.0, null: false
    t.boolean "stretch", default: false, null: false
    t.string "llm_model"
    t.text "caveat"
    t.jsonb "raw_response", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["story_id"], name: "index_biblical_analyses_on_story_id", unique: true
  end

  create_table "feed_sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.integer "kind", default: 1, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url"], name: "index_feed_sources_on_url", unique: true
  end

  create_table "stories", force: :cascade do |t|
    t.string "url", null: false
    t.string "title", null: false
    t.text "description"
    t.string "source_name", null: false
    t.integer "source_kind", default: 1, null: false
    t.string "image_url"
    t.datetime "published_at"
    t.integer "status", default: 0, null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_stories_on_published_at"
    t.index ["status"], name: "index_stories_on_status"
    t.index ["url"], name: "index_stories_on_url", unique: true
  end

  add_foreign_key "biblical_analyses", "stories"
end
