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

ActiveRecord::Schema[8.0].define(version: 2025_07_14_133926) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "author_type"
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "ai_logs", force: :cascade do |t|
    t.string "model"
    t.json "settings"
    t.text "query"
    t.text "response"
    t.integer "chat_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.decimal "total_cost", precision: 10, scale: 7
  end

  create_table "prompt_versions", force: :cascade do |t|
    t.bigint "prompt_id", null: false
    t.integer "version_number", null: false
    t.text "content", null: false
    t.text "change_summary"
    t.string "name", null: false
    t.text "description"
    t.string "category"
    t.json "metadata", default: {}
    t.boolean "is_current", default: false, null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_prompt_versions_on_created_at"
    t.index ["created_by_id"], name: "index_prompt_versions_on_created_by_id"
    t.index ["prompt_id", "is_current"], name: "index_prompt_versions_on_prompt_id_and_is_current"
    t.index ["prompt_id", "version_number"], name: "index_prompt_versions_on_prompt_id_and_version_number", unique: true
    t.index ["prompt_id"], name: "index_prompt_versions_on_prompt_id"
    t.index ["version_number"], name: "index_prompt_versions_on_version_number"
  end

  create_table "prompts", force: :cascade do |t|
    t.string "name", null: false
    t.text "content", null: false
    t.integer "current_version", default: 1, null: false
    t.string "status", default: "active", null: false
    t.text "description"
    t.string "category"
    t.json "metadata", default: {}
    t.bigint "created_by_id", null: false
    t.bigint "updated_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "tags"
    t.index ["category"], name: "index_prompts_on_category"
    t.index ["created_by_id"], name: "index_prompts_on_created_by_id"
    t.index ["current_version"], name: "index_prompts_on_current_version"
    t.index ["name"], name: "index_prompts_on_name", unique: true
    t.index ["status"], name: "index_prompts_on_status"
    t.index ["updated_by_id"], name: "index_prompts_on_updated_by_id"
  end

  add_foreign_key "prompt_versions", "admin_users", column: "created_by_id"
  add_foreign_key "prompt_versions", "prompts"
  add_foreign_key "prompts", "admin_users", column: "created_by_id"
  add_foreign_key "prompts", "admin_users", column: "updated_by_id"
end
