class AddColorToScenes < ActiveRecord::Migration[7.1]
  def change
    add_column :scenes, :color, :string
  end
end
