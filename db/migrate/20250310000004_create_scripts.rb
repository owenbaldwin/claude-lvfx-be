class CreateScripts < ActiveRecord::Migration[7.0]
  def change
    create_table :scripts do |t|
      t.references :production, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :version
      t.date :date

      t.timestamps
    end
  end
end