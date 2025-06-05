class CreateShotAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :shot_assets do |t|
      t.references :shot, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true

      t.timestamps
    end
  end
end
