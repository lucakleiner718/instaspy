class AddUsernameIndexToUsers < ActiveRecord::Migration
  def up
    remove_duplicated
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
  end

  def remove_duplicated
    con = ActiveRecord::Base.connection()
    res = con.execute('select id,username from users')
    data = {}
    res.each {|el| data[el[1]] ||= 0; data[el[1]] += 1 }
    duplicates = data.to_a.select{|el| el[1] > 1 }
    duplicates.each do |duplication|
      username = duplication[0]

      list = res.to_a.select{|el| el[1] == username}
      if list[0][0].present?
        origin = list.shift

        list.each do |user|
          dupl_user = User.find(user[0])
          con.execute("update media set user_id=#{origin[0]} where user_id=#{user[0]}")
          Follower.where(user_id: user[0]).update_all(user_id: origin[0])
          dupl_user.destroy
        end
      else
        User.where(username: nil).where('created_at < ?', 1.week.ago).destroy_all
      end
    end
  end
end
