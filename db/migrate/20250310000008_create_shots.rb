class CreateShots < ActiveRecord::Migration[7.0]
  def change
    create_table :shots do |t|
      t.references :action_beat, null: false, foreign_key: true
      t.string :number, null: false
      t.text :description
      t.string :camera_angle
      t.string :camera_movement
      t.string :status, default: 'planned'
      t.text :notes

      t.timestamps
    end
  end
end