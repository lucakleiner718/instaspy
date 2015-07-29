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

ActiveRecord::Schema.define(version: 20150728123733) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "feedly", force: :cascade do |t|
    t.string   "website",            limit: 255
    t.string   "feed_id",            limit: 255
    t.string   "feedly_url",         limit: 255
    t.integer  "subscribers_amount"
    t.datetime "grabbed_at"
    t.integer  "user_id"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "feedly", ["feed_id"], name: "index_feedly_on_feed_id", unique: true, using: :btree
  add_index "feedly", ["website"], name: "index_feedly_on_website", using: :btree

  create_table "followers", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "follower_id"
    t.datetime "followed_at"
    t.datetime "created_at",  null: false
  end

  add_index "followers", ["followed_at"], name: "index_followers_on_followed_at", using: :btree
  add_index "followers", ["follower_id"], name: "index_followers_on_follower_id", using: :btree
  add_index "followers", ["user_id", "follower_id"], name: "index_followers_on_user_id_and_follower_id", unique: true, using: :btree
  add_index "followers", ["user_id"], name: "index_followers_on_user_id", using: :btree

  create_table "instagram_accounts", force: :cascade do |t|
    t.string   "client_id",     limit: 255
    t.string   "client_secret", limit: 255
    t.string   "redirect_uri",  limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "instagram_accounts", ["client_id"], name: "index_instagram_accounts_on_client_id", unique: true, using: :btree

  create_table "instagram_logins", force: :cascade do |t|
    t.integer  "ig_id"
    t.string   "access_token", limit: 255
    t.integer  "account_id"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "instagram_logins", ["account_id"], name: "index_instagram_logins_on_account_id", using: :btree

  create_table "media", force: :cascade do |t|
    t.string   "insta_id",         limit: 255
    t.datetime "created_time"
    t.integer  "likes_amount"
    t.integer  "comments_amount"
    t.string   "link",             limit: 255
    t.decimal  "location_lat",                 precision: 10, scale: 6
    t.decimal  "location_lng",                 precision: 10, scale: 6
    t.string   "location_name",    limit: 255
    t.string   "location_city",    limit: 255
    t.string   "location_state",   limit: 255
    t.string   "location_country", limit: 255
    t.boolean  "location_present"
    t.text     "tag_names",                                             default: [],              array: true
    t.string   "image",            limit: 255
    t.integer  "user_id"
    t.datetime "created_at",                                                         null: false
    t.datetime "updated_at",                                                         null: false
  end

  add_index "media", ["created_at"], name: "index_media_on_created_at", using: :btree
  add_index "media", ["created_time"], name: "index_media_on_created_time", using: :btree
  add_index "media", ["insta_id"], name: "index_media_on_insta_id", unique: true, using: :btree
  add_index "media", ["location_city"], name: "index_media_on_location_city", using: :btree
  add_index "media", ["location_country"], name: "index_media_on_location_country", using: :btree
  add_index "media", ["location_state"], name: "index_media_on_location_state", using: :btree
  add_index "media", ["updated_at"], name: "index_media_on_updated_at", using: :btree
  add_index "media", ["user_id"], name: "index_media_on_user_id", using: :btree

  create_table "media_amount_stats", force: :cascade do |t|
    t.date     "date"
    t.integer  "amount"
    t.string   "action",     limit: 255
    t.datetime "updated_at"
  end

  add_index "media_amount_stats", ["date", "action"], name: "index_media_amount_stats_on_date_and_action", using: :btree

  create_table "media_tags", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "media_id"
  end

  add_index "media_tags", ["media_id", "tag_id"], name: "index_media_tags_on_media_id_and_tag_id", using: :btree
  add_index "media_tags", ["media_id"], name: "index_media_tags_on_media_id", using: :btree
  add_index "media_tags", ["tag_id"], name: "index_media_tags_on_tag_id", using: :btree

  create_table "observed_tags", force: :cascade do |t|
    t.integer  "tag_id"
    t.datetime "media_updated_at"
    t.boolean  "export_csv",       default: false
    t.boolean  "for_chart",        default: false
  end

  add_index "observed_tags", ["tag_id"], name: "index_observed_tags_on_tag_id", unique: true, using: :btree

  create_table "reports", force: :cascade do |t|
    t.string   "format",          limit: 255
    t.string   "original_input",  limit: 255
    t.string   "processed_input", limit: 255
    t.string   "status",          limit: 255
    t.integer  "progress",                    default: 0
    t.json     "jobs",                        default: {}
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "result_data",     limit: 255
    t.string   "notify_email",    limit: 255
    t.date     "date_from"
    t.date     "date_to"
    t.json     "data",                        default: {}
    t.text     "tmp_list1",                   default: [],              array: true
    t.string   "note",            limit: 255
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.text     "output_data",                 default: [],              array: true
    t.text     "not_processed",               default: [],              array: true
    t.text     "steps",                       default: [],              array: true
    t.json     "amounts"
  end

  create_table "stats", force: :cascade do |t|
    t.string   "key",        limit: 255
    t.string   "value",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "stats", ["key"], name: "index_stats_on_key", using: :btree

  create_table "tag_media_counters", force: :cascade do |t|
    t.integer  "tag_id"
    t.integer  "media_count", default: 0
    t.datetime "updated_at",              null: false
  end

  add_index "tag_media_counters", ["tag_id"], name: "index_tag_media_counters_on_tag_id", using: :btree

  create_table "tag_stats", force: :cascade do |t|
    t.integer "amount"
    t.date    "date"
    t.integer "tag_id"
  end

  add_index "tag_stats", ["tag_id"], name: "index_tag_stats_on_tag_id", using: :btree

  create_table "tags", force: :cascade do |t|
    t.string "name", limit: 255
  end

  add_index "tags", ["name"], name: "index_tags_on_name", unique: true, using: :btree

  create_table "track_users", force: :cascade do |t|
    t.integer "user_id"
    t.boolean "followees", default: false
    t.boolean "followers", default: false
  end

  add_index "track_users", ["user_id"], name: "index_track_users_on_user_id", unique: true, using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "insta_id",                limit: 20
    t.string   "username",                limit: 255
    t.string   "full_name",               limit: 255
    t.string   "bio",                     limit: 255
    t.string   "website",                 limit: 255
    t.integer  "follows"
    t.integer  "followed_by"
    t.integer  "media_amount"
    t.boolean  "private",                             default: false
    t.datetime "grabbed_at"
    t.string   "email",                   limit: 255
    t.string   "location_country",        limit: 255
    t.string   "location_state",          limit: 255
    t.string   "location_city",           limit: 255
    t.datetime "location_updated_at"
    t.integer  "avg_likes"
    t.datetime "avg_likes_updated_at"
    t.integer  "avg_comments"
    t.datetime "avg_comments_updated_at"
    t.datetime "followers_updated_at"
    t.datetime "followees_updated_at"
    t.datetime "created_at",                                          null: false
    t.datetime "updated_at",                                          null: false
  end

  add_index "users", ["avg_comments"], name: "index_users_on_avg_comments", using: :btree
  add_index "users", ["avg_comments_updated_at"], name: "index_users_on_avg_comments_updated_at", using: :btree
  add_index "users", ["avg_likes"], name: "index_users_on_avg_likes", using: :btree
  add_index "users", ["avg_likes_updated_at"], name: "index_users_on_avg_likes_updated_at", using: :btree
  add_index "users", ["created_at"], name: "index_users_on_created_at", using: :btree
  add_index "users", ["email"], name: "index_users_on_email", using: :btree
  add_index "users", ["followed_by"], name: "index_users_on_followed_by", using: :btree
  add_index "users", ["follows"], name: "index_users_on_follows", using: :btree
  add_index "users", ["grabbed_at"], name: "index_users_on_grabbed_at", using: :btree
  add_index "users", ["insta_id"], name: "index_users_on_insta_id", unique: true, using: :btree
  add_index "users", ["location_city"], name: "index_users_on_location_city", using: :btree
  add_index "users", ["location_country"], name: "index_users_on_location_country", using: :btree
  add_index "users", ["location_state"], name: "index_users_on_location_state", using: :btree
  add_index "users", ["media_amount"], name: "index_users_on_media_amount", using: :btree
  add_index "users", ["updated_at"], name: "index_users_on_updated_at", using: :btree
  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree
  add_index "users", ["website"], name: "index_users_on_website", using: :btree

end
