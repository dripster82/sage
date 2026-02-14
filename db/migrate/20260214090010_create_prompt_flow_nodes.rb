class CreatePromptFlowNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_flow_nodes do |t|
      t.references :prompt_flow, null: false, foreign_key: true
      t.string :node_type, null: false
      t.references :prompt, foreign_key: true
      t.integer :position_x
      t.integer :position_y
      t.json :config, default: {}
      t.json :input_ports, default: {}
      t.json :output_ports, default: {}

      t.timestamps
    end

    add_index :prompt_flow_nodes, :node_type
  end
end
