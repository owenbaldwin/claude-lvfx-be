class AddColorToScripts < ActiveRecord::Migration[7.1]
  def change
    add_column :scripts, :color, :string
  end
end
