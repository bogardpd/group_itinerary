# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160717213656) do

  create_table "airlines", force: :cascade do |t|
    t.string "iata_code"
    t.string "name"
  end

  add_index "airlines", ["iata_code"], name: "index_airlines_on_iata_code", unique: true

  create_table "events", force: :cascade do |t|
    t.text     "event_name"
    t.text     "arriving_timezone"
    t.text     "departing_timezone"
    t.integer  "user_id"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.string   "share_link"
    t.text     "note"
  end

  add_index "events", ["user_id"], name: "index_events_on_user_id"

  create_table "flights", force: :cascade do |t|
    t.text     "airline_iata"
    t.integer  "flight_number"
    t.datetime "departure_datetime"
    t.text     "departure_airport_iata"
    t.datetime "arrival_datetime"
    t.text     "arrival_airport_iata"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "section_id"
    t.integer  "airline_id"
  end

  create_table "sections", force: :cascade do |t|
    t.text     "traveler_name"
    t.text     "traveler_note"
    t.text     "pickup_info"
    t.boolean  "is_arrival"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "event_id"
  end

  add_index "sections", ["event_id"], name: "index_sections_on_event_id"

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.string   "email"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "password_digest"
    t.string   "remember_digest"
    t.boolean  "admin",           default: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true

end
