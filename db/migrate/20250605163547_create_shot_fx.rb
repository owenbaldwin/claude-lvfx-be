class CreateShotFx < ActiveRecord::Migration[7.1]
  def change
    create_table :shot_fxes do |t|
      t.references :shot, null: false, foreign_key: true
      t.references :fx, null: false, foreign_key: true

      t.timestamps
    end
  end
end
