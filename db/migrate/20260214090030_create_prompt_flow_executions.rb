class CreatePromptFlowExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_flow_executions do |t|
      t.references :prompt_flow, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.json :inputs, default: {}
      t.json :outputs, default: {}
      t.json :execution_log, default: []
      t.text :error_message

      t.timestamps
    end

    add_index :prompt_flow_executions, :status
  end
end
