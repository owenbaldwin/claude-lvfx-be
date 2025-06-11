class AddCategoryToAssumptions < ActiveRecord::Migration[7.1]
  def change
    add_column :assumptions, :category, :string
  end
end
