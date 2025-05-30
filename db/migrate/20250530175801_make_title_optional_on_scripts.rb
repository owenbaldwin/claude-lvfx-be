class MakeTitleOptionalOnScripts < ActiveRecord::Migration[7.0]
  def change
    change_column_null :scripts, :title, true
  end
end
