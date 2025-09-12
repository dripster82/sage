class AddModelToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_reference :prompts, :allowed_model, null: true, foreign_key: true
  end
end
