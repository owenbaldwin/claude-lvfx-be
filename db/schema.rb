# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_03_11_191451) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_beats", force: :cascade do |t|
    t.bigint "scene_id", null: false
    t.text "description"
    t.integer "number"
    t.text "dialogue"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "script_id"
    t.bigint "production_id", null: false
    t.bigint "sequence_id", null: false
    t.string "beat_type", default: "action", null: false
    t.string "text", null: false
    t.index ["production_id"], name: "index_action_beats_on_production_id"
    t.index ["scene_id", "number"], name: "index_action_beats_on_scene_id_and_number", unique: true
    t.index ["scene_id"], name: "index_action_beats_on_scene_id"
    t.index ["script_id"], name: "index_action_beats_on_script_id"
    t.index ["sequence_id"], name: "index_action_beats_on_sequence_id"
  end

  create_table "production_users", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "production_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["production_id"], name: "index_production_users_on_production_id"
    t.index ["user_id", "production_id"], name: "index_production_users_on_user_id_and_production_id", unique: true
    t.index ["user_id"], name: "index_production_users_on_user_id"
  end

  create_table "productions", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.date "start_date"
    t.date "end_date"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scenes", force: :cascade do |t|
    t.bigint "sequence_id", null: false
    t.string "name"
    t.text "description"
    t.string "location"
    t.string "day_night"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "script_id"
    t.bigint "production_id", null: false
    t.integer "number", null: false
    t.string "int_ext", default: "interior", null: false
    t.string "length"
    t.index ["production_id"], name: "index_scenes_on_production_id"
    t.index ["script_id"], name: "index_scenes_on_script_id"
    t.index ["sequence_id", "number"], name: "index_scenes_on_sequence_id_and_number", unique: true
    t.index ["sequence_id"], name: "index_scenes_on_sequence_id"
  end

  create_table "scripts", force: :cascade do |t|
    t.bigint "production_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "version"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["production_id"], name: "index_scripts_on_production_id"
  end

  create_table "sequences", force: :cascade do |t|
    t.bigint "script_id"
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "production_id", null: false
    t.integer "number", null: false
    t.string "prefix"
    t.index ["production_id"], name: "index_sequences_on_production_id"
    t.index ["script_id", "number"], name: "index_sequences_on_script_id_and_number", unique: true
    t.index ["script_id"], name: "index_sequences_on_script_id"
  end

  create_table "shots", force: :cascade do |t|
    t.bigint "action_beat_id", null: false
    t.text "description", null: false
    t.string "camera_angle", null: false
    t.string "camera_movement", null: false
    t.string "status", default: "pending"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "script_id"
    t.bigint "production_id", null: false
    t.bigint "scene_id", null: false
    t.bigint "sequence_id", null: false
    t.integer "number", null: false
    t.string "vfx", default: "no", null: false
    t.time "duration"
    t.index ["action_beat_id", "number"], name: "index_shots_on_action_beat_id_and_number", unique: true
    t.index ["action_beat_id"], name: "index_shots_on_action_beat_id"
    t.index ["production_id"], name: "index_shots_on_production_id"
    t.index ["scene_id"], name: "index_shots_on_scene_id"
    t.index ["script_id"], name: "index_shots_on_script_id"
    t.index ["sequence_id"], name: "index_shots_on_sequence_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name"
    t.string "last_name"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "action_beats", "productions"
  add_foreign_key "action_beats", "scenes"
  add_foreign_key "action_beats", "scripts"
  add_foreign_key "action_beats", "sequences"
  add_foreign_key "production_users", "productions"
  add_foreign_key "production_users", "users"
  add_foreign_key "scenes", "productions"
  add_foreign_key "scenes", "scripts"
  add_foreign_key "scenes", "sequences"
  add_foreign_key "scripts", "productions"
  add_foreign_key "sequences", "productions"
  add_foreign_key "sequences", "scripts"
  add_foreign_key "shots", "action_beats"
  add_foreign_key "shots", "productions"
  add_foreign_key "shots", "scenes"
  add_foreign_key "shots", "scripts"
  add_foreign_key "shots", "sequences"
end
