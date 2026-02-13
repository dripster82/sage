class AddDurationMsToAiLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_logs, :duration_ms, :integer
  end
end
