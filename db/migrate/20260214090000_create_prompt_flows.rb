class CreatePromptFlows < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_flows do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: 'draft'
      t.integer :version_number, null: false, default: 1
      t.boolean :is_current, null: false, default: true
      t.integer :max_executions, null: false, default: 20
      t.references :created_by, null: false, foreign_key: { to_table: :admin_users }
      t.references :updated_by, null: false, foreign_key: { to_table: :admin_users }

      t.timestamps
    end

    add_index :prompt_flows, :name, unique: true
    add_index :prompt_flows, :status
    add_index :prompt_flows, :is_current
    add_index :prompt_flows, :version_number
  end
end
