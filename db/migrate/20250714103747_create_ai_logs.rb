class CreateAiLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_logs do |t|
      t.string :model
      t.json :settings
      t.text :query
      t.text :response
      t.integer :chat_id

      t.timestamps
    end
  end
end
