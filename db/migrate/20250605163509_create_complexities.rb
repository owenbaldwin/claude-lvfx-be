class CreateComplexities < ActiveRecord::Migration[7.1]
  def change
    create_table :complexities do |t|
      t.string :level
      t.text :description
      t.references :production, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
