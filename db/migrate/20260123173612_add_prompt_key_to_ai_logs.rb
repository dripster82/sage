class AddPromptKeyToAiLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_logs, :prompt_key, :text
  end
end
