class CreateAllowedModels < ActiveRecord::Migration[8.0]
  def change
    create_table :allowed_models do |t|
      t.string :name, null: false
      t.string :model, null: false
      t.boolean :active, default: true, null: false
      t.string :provider, null: false
      t.integer :context_size
      t.boolean :default, default: false, null: false

      t.timestamps
    end

    add_index :allowed_models, :model, unique: true
    add_index :allowed_models, :active
    add_index :allowed_models, :default
    add_index :allowed_models, :provider
  end
end
