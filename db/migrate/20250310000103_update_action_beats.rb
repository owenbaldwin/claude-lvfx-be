class UpdateActionBeats < ActiveRecord::Migration[7.0]
  def change
    # Update action_beats table
    change_table :action_beats do |t|
      # Add foreign keys
      t.references :script, null: false, foreign_key: true
      t.references :production, null: false, foreign_key: true
      t.references :sequence, null: false, foreign_key: true
      
      # Modify existing columns
      t.rename :order_number, :number
      
      # Add the beat_type field to replace description
      t.string :beat_type, null: false, default: 'action'
      
      # Add text field (main content)
      t.string :text, null: false
      
      # Make description optional
      t.change :description, :text, null: true
    end
    
    # Add index for uniqueness of number within a scene
    add_index :action_beats, [:scene_id, :number], unique: true
  end
end