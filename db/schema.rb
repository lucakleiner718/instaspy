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

ActiveRecord::Schema.define(version: 20140909053853) do

  create_table "media", force: true do |t|
    t.string   "insta_id"
    t.string   "insta_type"
    t.string   "filter"
    t.text     "text"
    t.integer  "likes_amount"
    t.string   "link"
    t.integer  "user_id"
    t.datetime "created_time"
    t.text     "images"
    t.text     "videos"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "media_tags", id: false, force: true do |t|
    t.integer "media_id"
    t.integer "tag_id"
  end

  add_index "media_tags", ["media_id"], name: "index_media_tags_on_media_id", using: :btree
  add_index "media_tags", ["tag_id"], name: "index_media_tags_on_tag_id", using: :btree

  create_table "settings", force: true do |t|
    t.string   "key"
    t.text     "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tags", force: true do |t|
    t.string   "name"
    t.integer  "media_count"
    t.boolean  "observed"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "grabs_users_csv", default: false
  end

  create_table "users", force: true do |t|
    t.integer  "insta_id"
    t.string   "username"
    t.string   "full_name"
    t.string   "profile_picture"
    t.text     "bio"
    t.string   "website"
    t.integer  "follows"
    t.integer  "followed_by"
    t.integer  "media_amount"
    t.boolean  "private",         default: false
    t.datetime "grabbed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
