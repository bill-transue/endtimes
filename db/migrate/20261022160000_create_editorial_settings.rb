class CreateEditorialSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :editorial_settings do |t|
      t.boolean :singleton, null: false, default: true
      t.integer :focus, null: false, default: 0
      t.jsonb :gnews_queries, null: false, default: []
      t.float :min_prophecy_relevance, null: false, default: 0.35
      t.integer :daily_publish_cap

      t.timestamps
    end

    add_index :editorial_settings, :singleton, unique: true
  end
end
