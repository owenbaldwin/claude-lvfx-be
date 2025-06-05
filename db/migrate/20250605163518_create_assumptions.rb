class CreateAssumptions < ActiveRecord::Migration[7.1]
  def change
    create_table :assumptions do |t|
      t.string :name
      t.text :description
      t.references :complexity, null: false, foreign_key: true
      t.references :production, null: false, foreign_key: true

      t.timestamps
    end
  end
end
