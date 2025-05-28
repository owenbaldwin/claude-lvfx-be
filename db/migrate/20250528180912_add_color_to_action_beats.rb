class AddColorToActionBeats < ActiveRecord::Migration[7.1]
  def change
    add_column :action_beats, :color, :string
  end
end
