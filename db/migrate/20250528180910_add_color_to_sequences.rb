class AddColorToSequences < ActiveRecord::Migration[7.1]
  def change
    add_column :sequences, :color, :string
  end
end
