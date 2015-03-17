require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get followers" do
    get :followers
    assert_response :success
  end

  test "should get followees" do
    get :followees
    assert_response :success
  end

end
