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

ActiveRecord::Schema[7.1].define(version: 2025_06_03_190734) do
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
    t.boolean "is_active", default: false
    t.integer "version_number"
    t.bigint "source_beat_id"
    t.string "color"
    t.index ["production_id", "scene_id", "number", "version_number"], name: "idx_on_production_id_scene_id_number_version_number_a81d17a7b0"
    t.index ["production_id"], name: "index_action_beats_on_production_id"
    t.index ["scene_id"], name: "index_action_beats_on_scene_id"
    t.index ["script_id"], name: "index_action_beats_on_script_id"
    t.index ["sequence_id"], name: "index_action_beats_on_sequence_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "character_appearances", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.bigint "scene_id"
    t.bigint "action_beat_id"
    t.bigint "shot_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_beat_id"], name: "index_character_appearances_on_action_beat_id"
    t.index ["character_id"], name: "index_character_appearances_on_character_id"
    t.index ["scene_id"], name: "index_character_appearances_on_scene_id"
    t.index ["shot_id"], name: "index_character_appearances_on_shot_id"
  end

  create_table "characters", force: :cascade do |t|
    t.string "full_name"
    t.text "description"
    t.string "actor"
    t.bigint "production_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["production_id"], name: "index_characters_on_production_id"
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
    t.boolean "is_active", default: false
    t.integer "version_number"
    t.bigint "source_scene_id"
    t.string "color"
    t.index ["production_id", "number", "version_number"], name: "index_scenes_on_production_id_and_number_and_version_number"
    t.index ["production_id"], name: "index_scenes_on_production_id"
    t.index ["script_id"], name: "index_scenes_on_script_id"
    t.index ["sequence_id"], name: "index_scenes_on_sequence_id"
  end

  create_table "scripts", force: :cascade do |t|
    t.bigint "production_id", null: false
    t.string "title"
    t.text "description"
    t.integer "version_number"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "previous_script_id"
    t.string "color"
    t.jsonb "scenes_data_json", default: {}
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
    t.integer "version_number"
    t.bigint "source_sequence_id"
    t.boolean "is_active", default: false
    t.string "color"
    t.index ["production_id", "number", "version_number"], name: "index_sequences_on_production_id_and_number_and_version_number"
    t.index ["production_id"], name: "index_sequences_on_production_id"
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
    t.integer "version_number"
    t.bigint "source_shot_id"
    t.boolean "is_active", default: false
    t.string "color"
    t.index ["action_beat_id"], name: "index_shots_on_action_beat_id"
    t.index ["production_id", "scene_id", "number", "version_number"], name: "idx_on_production_id_scene_id_number_version_number_6cd32e9257"
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

  add_foreign_key "action_beats", "action_beats", column: "source_beat_id"
  add_foreign_key "action_beats", "productions"
  add_foreign_key "action_beats", "scenes"
  add_foreign_key "action_beats", "scripts"
  add_foreign_key "action_beats", "sequences"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "character_appearances", "action_beats"
  add_foreign_key "character_appearances", "characters"
  add_foreign_key "character_appearances", "scenes"
  add_foreign_key "character_appearances", "shots"
  add_foreign_key "characters", "productions"
  add_foreign_key "production_users", "productions"
  add_foreign_key "production_users", "users"
  add_foreign_key "scenes", "productions"
  add_foreign_key "scenes", "scenes", column: "source_scene_id"
  add_foreign_key "scenes", "scripts"
  add_foreign_key "scenes", "sequences"
  add_foreign_key "scripts", "productions"
  add_foreign_key "scripts", "scripts", column: "previous_script_id"
  add_foreign_key "sequences", "productions"
  add_foreign_key "sequences", "scripts"
  add_foreign_key "sequences", "sequences", column: "source_sequence_id"
  add_foreign_key "shots", "action_beats"
  add_foreign_key "shots", "productions"
  add_foreign_key "shots", "scenes"
  add_foreign_key "shots", "scripts"
  add_foreign_key "shots", "sequences"
  add_foreign_key "shots", "shots", column: "source_shot_id"
end
