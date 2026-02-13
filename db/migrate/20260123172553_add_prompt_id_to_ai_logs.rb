class AddPromptIdToAiLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_logs, :prompt_id, :integer
  end
end
