class AddSessionUuidToAiLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_logs, :session_uuid, :uuid
  end
end
