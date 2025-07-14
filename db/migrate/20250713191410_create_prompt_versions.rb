class CreatePromptVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_versions do |t|
      t.references :prompt, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text :content, null: false
      t.text :change_summary
      t.string :name, null: false
      t.text :description
      t.string :category
      t.json :metadata, default: {}
      t.boolean :is_current, default: false, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :admin_users }

      t.timestamps
    end

    add_index :prompt_versions, [:prompt_id, :version_number], unique: true
    add_index :prompt_versions, [:prompt_id, :is_current]
    add_index :prompt_versions, :version_number
    add_index :prompt_versions, :created_at
  end
end
