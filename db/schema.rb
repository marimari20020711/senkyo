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

ActiveRecord::Schema[7.2].define(version: 2025_07_11_090800) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bill_supports", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.string "supportable_type", null: false
    t.bigint "supportable_id", null: false
    t.string "support_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_bill_supports_on_bill_id"
    t.index ["supportable_type", "supportable_id"], name: "index_bill_supports_on_supportable"
  end

  create_table "bills", force: :cascade do |t|
    t.string "title"
    t.string "kind"
    t.string "discussion_status"
    t.text "summary_text"
    t.string "summary_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "session"
    t.string "number"
    t.date "pre_received_date"
    t.date "pre_refer_date"
    t.string "pre_refer_committee"
    t.date "received_date"
    t.date "refer_date"
    t.string "refer_committee"
    t.text "ai_summary"
    t.string "body_link"
    t.text "body_text"
    t.string "sangi_hp_body_link"
    t.text "sangi_hp_body_text"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "politician_groups", force: :cascade do |t|
    t.bigint "politician_id", null: false
    t.bigint "group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_politician_groups_on_group_id"
    t.index ["politician_id"], name: "index_politician_groups_on_politician_id"
  end

  create_table "politicians", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_reading"
    t.string "real_name"
    t.string "name_of_house"
    t.string "district"
    t.string "winning_year"
    t.date "birth"
    t.text "position"
    t.string "winning_count"
    t.text "profile"
    t.string "term_end"
    t.string "normalized_name"
  end

  create_table "speeches", force: :cascade do |t|
    t.bigint "politician_id", null: false
    t.date "meeting_date"
    t.string "source_url"
    t.text "body"
    t.string "session"
    t.integer "speech_order"
    t.string "name_of_meeting"
    t.string "name_of_house"
    t.string "external_speech_id"
    t.text "ai_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["politician_id"], name: "index_speeches_on_politician_id"
  end

  add_foreign_key "bill_supports", "bills"
  add_foreign_key "politician_groups", "groups"
  add_foreign_key "politician_groups", "politicians"
  add_foreign_key "speeches", "politicians"
end
