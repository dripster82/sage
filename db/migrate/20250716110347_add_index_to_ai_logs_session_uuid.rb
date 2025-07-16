class AddIndexToAiLogsSessionUuid < ActiveRecord::Migration[8.0]
  def change
    add_index :ai_logs, :session_uuid
  end
end
