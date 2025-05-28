class AddPreviousScriptToScripts < ActiveRecord::Migration[7.1]
  def change
    add_column :scripts, :previous_script_id, :bigint
    add_foreign_key :scripts, :scripts, column: :previous_script_id
  end
end
