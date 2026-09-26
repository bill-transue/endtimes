class CreateBiblicalAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :biblical_analyses do |t|
      t.references :story, null: false, foreign_key: true, index: { unique: true }
      t.text :summary, null: false
      t.jsonb :themes, null: false, default: []
      t.jsonb :connections, null: false, default: []
      t.jsonb :verse_refs, null: false, default: []
      t.float :prophecy_relevance, null: false, default: 0.0
      t.boolean :stretch, null: false, default: false
      t.string :llm_model
      t.text :caveat
      t.jsonb :raw_response, null: false, default: {}

      t.timestamps
    end
  end
end
