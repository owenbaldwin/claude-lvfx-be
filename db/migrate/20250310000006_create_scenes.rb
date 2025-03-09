class CreateScenes < ActiveRecord::Migration[7.0]
  def change
    create_table :scenes do |t|
      t.references :sequence, null: false, foreign_key: true
      t.string :number, null: false
      t.string :name
      t.text :description
      t.string :setting
      t.string :time_of_day

      t.timestamps
    end
    
    add_index :scenes, [:sequence_id, :number], unique: true
  end
end