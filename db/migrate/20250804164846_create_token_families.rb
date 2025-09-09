class CreateTokenFamilies < ActiveRecord::Migration[8.0]
  def change
    create_table :token_families do |t|
      t.string :family_id, null: false
      t.references :admin_user, null: false, foreign_key: true
      t.string :latest_token_id, null: false
      t.integer :version, null: false, default: 1
      t.string :device_fingerprint, null: false

      t.timestamps
    end

    add_index :token_families, :family_id, unique: true
    add_index :token_families, [:admin_user_id, :device_fingerprint]
  end
end
