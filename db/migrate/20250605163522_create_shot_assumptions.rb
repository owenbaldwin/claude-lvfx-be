class CreateShotAssumptions < ActiveRecord::Migration[7.1]
  def change
    create_table :shot_assumptions do |t|
      t.references :shot, null: false, foreign_key: true
      t.references :assumption, null: false, foreign_key: true

      t.timestamps
    end
  end
end
