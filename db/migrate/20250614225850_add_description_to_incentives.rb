class AddDescriptionToIncentives < ActiveRecord::Migration[7.1]
  def change
    add_column :incentives, :description, :text
  end
end
