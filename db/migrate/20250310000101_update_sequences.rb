class UpdateSequences < ActiveRecord::Migration[7.0]
  def change
    # Update sequences table
    change_table :sequences do |t|
      # Add production_id foreign key
      t.references :production, null: false, foreign_key: true
      
      # Change number from string to integer
      t.remove :number
      t.integer :number, null: false
      
      # Add prefix field
      t.string :prefix
    end
    
    # Re-add the unique index which was dropped when we removed the column
    add_index :sequences, [:script_id, :number], unique: true
  end
end