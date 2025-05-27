class AddIsActiveToSequences < ActiveRecord::Migration[7.1]
  def change
    add_column :sequences, :is_active, :boolean, default: false
  end
end
