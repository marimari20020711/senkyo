require "test_helper"

class PoliticiansControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get politicians_show_url
    assert_response :success
  end
end
