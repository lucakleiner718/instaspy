require 'test_helper'

class ReportsControllerTest < ActionController::TestCase
  test "should get followers" do
    get :followers
    assert_response :success
  end

end
