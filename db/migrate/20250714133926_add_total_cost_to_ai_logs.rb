class AddTotalCostToAiLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_logs, :total_cost, :decimal, precision: 10, scale: 7, null: true
  end
end
