class AddTokenFieldsToAiLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_logs, :input_tokens, :integer
    add_column :ai_logs, :output_tokens, :integer

    # Make response field optional (allow null)
    change_column_null :ai_logs, :response, true
  end
end
