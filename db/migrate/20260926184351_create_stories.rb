class CreateStories < ActiveRecord::Migration[8.1]
  def change
    create_table :stories do |t|
      t.string :url, null: false
      t.string :title, null: false
      t.text :description
      t.string :source_name, null: false
      t.integer :source_kind, null: false, default: 1
      t.string :image_url
      t.datetime :published_at
      t.integer :status, null: false, default: 0
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :stories, :url, unique: true
    add_index :stories, :status
    add_index :stories, :published_at
  end
end
