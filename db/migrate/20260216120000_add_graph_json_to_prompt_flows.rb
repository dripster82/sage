class AddGraphJsonToPromptFlows < ActiveRecord::Migration[8.0]
  def change
    add_column :prompt_flows, :graph_json, :jsonb, null: false, default: {}

    remove_index :prompt_flows, :name
    add_index :prompt_flows, %i[name version_number], unique: true
  end
end
