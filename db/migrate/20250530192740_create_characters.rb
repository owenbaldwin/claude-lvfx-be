class CreateCharacters < ActiveRecord::Migration[7.1]
  def change
    create_table :characters do |t|
      t.string :full_name
      t.text :description
      t.string :actor
      t.references :production, null: false, foreign_key: true

      t.timestamps
    end
  end
end
