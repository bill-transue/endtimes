class CreateFeedSources < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_sources do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.integer :kind, null: false, default: 1
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :feed_sources, :url, unique: true
  end
end
