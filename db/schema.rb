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

ActiveRecord::Schema.define(version: 20150212075946) do

  create_table "followers", force: true do |t|
    t.integer  "user_id"
    t.integer  "follower_id"
    t.datetime "created_at"
  end

  create_table "instagram_accounts", force: true do |t|
    t.string   "client_id"
    t.string   "client_secret"
    t.string   "redirect_uri"
    t.string   "access_token"
    t.boolean  "login_process", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "instagram_accounts", ["client_id"], name: "index_instagram_accounts_on_client_id", unique: true, using: :btree

  create_table "media", force: true do |t|
    t.string   "insta_id"
    t.integer  "user_id"
    t.datetime "created_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "likes_amount"
    t.integer  "comments_amount"
    t.string   "link"
    t.float    "location_lat",     limit: 53
    t.float    "location_lng",     limit: 53
    t.string   "location_name"
    t.string   "location_city"
    t.string   "location_state"
    t.string   "location_country"
    t.boolean  "location_present"
  end

  add_index "media", ["insta_id"], name: "index_media_on_insta_id", unique: true, using: :btree
  add_index "media", ["user_id"], name: "index_media_on_user_id", using: :btree

  create_table "media_tags", id: false, force: true do |t|
    t.integer "media_id"
    t.integer "tag_id"
  end

  add_index "media_tags", ["media_id"], name: "index_media_tags_on_media_id", using: :btree
  add_index "media_tags", ["tag_id"], name: "index_media_tags_on_tag_id", using: :btree

  create_table "observed_tags", force: true do |t|
    t.integer  "tag_id"
    t.boolean  "export_csv",       default: false
    t.boolean  "for_chart",        default: false
    t.datetime "media_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "settings", force: true do |t|
    t.string   "key"
    t.text     "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_stats", force: true do |t|
    t.integer "tag_id"
    t.integer "amount"
    t.date    "date"
  end

  create_table "tags", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
  end

  add_index "tags", ["name"], name: "index_tags_on_name", unique: true, using: :btree

  create_table "track_users", force: true do |t|
    t.integer  "user_id"
    t.boolean  "followees",  default: false
    t.boolean  "followers",  default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.integer  "insta_id"
    t.string   "username"
    t.string   "full_name"
    t.text     "bio"
    t.string   "website"
    t.integer  "follows"
    t.integer  "followed_by"
    t.integer  "media_amount"
    t.boolean  "private",      default: false
    t.datetime "grabbed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email"
  end

  add_index "users", ["email"], name: "index_users_on_email", using: :btree
  add_index "users", ["insta_id"], name: "index_users_on_insta_id", unique: true, using: :btree
  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree
  add_index "users", ["website"], name: "index_users_on_website", using: :btree

end
