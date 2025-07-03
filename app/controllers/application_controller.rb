class ApplicationController < ActionController::Base
  before_action :set_navbar_searches
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  private

  def set_navbar_searches
    @bill_q = Bill.ransack(params[:bill_q])
    @politician_q = Politician.ransack(params[:politician_q])
    @group_q = Group.ransack(params[:group_q])
  end
end
