class AddPricingToAllowedModels < ActiveRecord::Migration[8.0]
  def change
    add_column :allowed_models, :pricing_input, :decimal, precision: 10, scale: 2
    add_column :allowed_models, :pricing_output, :decimal, precision: 10, scale: 2
  end
end
