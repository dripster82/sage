class CreatePromptFlowEdges < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_flow_edges do |t|
      t.references :prompt_flow, null: false, foreign_key: true
      t.references :source_node, null: false, foreign_key: { to_table: :prompt_flow_nodes }
      t.references :target_node, null: false, foreign_key: { to_table: :prompt_flow_nodes }
      t.string :source_port, null: false
      t.string :target_port, null: false
      t.string :validation_status

      t.timestamps
    end

    add_index :prompt_flow_edges, :source_node_id, if_not_exists: true
    add_index :prompt_flow_edges, :target_node_id, if_not_exists: true
  end
end
