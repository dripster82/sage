class AddTagsToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_column :prompts, :tags, :text
  end
end
