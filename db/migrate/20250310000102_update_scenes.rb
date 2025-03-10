class UpdateScenes < ActiveRecord::Migration[7.0]
  def change
    # Update scenes table
    change_table :scenes do |t|
      # Add foreign keys
      t.references :script, null: false, foreign_key: true
      t.references :production, null: false, foreign_key: true
      
      # Change number from string to integer
      t.remove :number
      t.integer :number, null: false
      
      # Rename and modify existing columns to match requirements
      t.rename :setting, :location
      t.rename :time_of_day, :day_night
      
      # Add new fields
      t.string :int_ext, null: false, default: 'interior'
      t.string :length
    end
    
    # Re-add the unique index which was dropped when we removed the column
    add_index :scenes, [:sequence_id, :number], unique: true
  end
end