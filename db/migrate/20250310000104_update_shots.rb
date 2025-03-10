class UpdateShots < ActiveRecord::Migration[7.0]
  def change
    # Update shots table
    change_table :shots do |t|
      # Add foreign keys
      t.references :script, null: false, foreign_key: true
      t.references :production, null: false, foreign_key: true
      t.references :scene, null: false, foreign_key: true
      t.references :sequence, null: false, foreign_key: true
      
      # Change number from string to integer
      t.remove :number
      t.integer :number, null: false
      
      # Add required fields
      t.string :vfx, null: false, default: 'no'
      t.time :duration
      
      # Make description required
      t.change :description, :text, null: false
      
      # Make camera fields required
      t.change :camera_angle, :string, null: false
      t.change :camera_movement, :string, null: false
    end
    
    # Add index for uniqueness of number within an action beat
    add_index :shots, [:action_beat_id, :number], unique: true
  end
end