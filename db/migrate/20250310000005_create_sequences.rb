class CreateSequences < ActiveRecord::Migration[7.0]
  def change
    create_table :sequences do |t|
      t.references :script, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :name
      t.text :description

      t.timestamps
    end
    add_index :sequences, [:script_id, :number], unique: true
  end
end