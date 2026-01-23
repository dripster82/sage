class AddCreditsToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_column :prompts, :credits, :integer, default: 1, null: false
  end
end
