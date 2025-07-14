class GroupsController < ApplicationController
  def index
    @q = Group.ransack(params[:q])
    @groups = @q.result(distinct: true)
  end
  
  def show
    @group = Group.find(params[:id])
    @bill_supports = @group.bill_supports.includes(:bill)

    @propose_bills = @bill_supports.select { |s| s.support_type == "propose" }.map(&:bill)
    @agree_bills = @bill_supports.select { |s| s.support_type == "agree" }.map(&:bill)
    @disagree_bills = @bill_supports.select { |s| s.support_type == "disagree" }.map(&:bill)
  end

    # app/controllers/groups_controller.rb
  def index
    @groups = Group.all.sort_by { |g| g.name.to_s.tr('ぁ-んァ-ン', 'あ-んあ-ん') }
  end
end
