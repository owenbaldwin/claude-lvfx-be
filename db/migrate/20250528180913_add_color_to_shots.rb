class AddColorToShots < ActiveRecord::Migration[7.1]
  def change
    add_column :shots, :color, :string
  end
end
