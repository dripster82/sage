class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.string :name, null: false
      t.text :content, null: false
      t.integer :current_version, default: 1, null: false
      t.string :status, default: 'active', null: false
      t.text :description
      t.string :category
      t.json :metadata, default: {}
      t.references :created_by, null: false, foreign_key: { to_table: :admin_users }
      t.references :updated_by, null: false, foreign_key: { to_table: :admin_users }

      t.timestamps
    end

    add_index :prompts, :status
    add_index :prompts, :name, unique: true
    add_index :prompts, :category
    add_index :prompts, :current_version
  end
end
