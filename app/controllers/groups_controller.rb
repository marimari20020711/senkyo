class GroupsController < ApplicationController
  def show
    @group = Group.find(params[:id])
    @bill_supports = @group.bill_supports.includes(:bill)

    @propose_bills = @bill_supports.select { |s| s.support_type == "propose" }.map(&:bill)
    @agree_bills = @bill_supports.select { |s| s.support_type == "agree" }.map(&:bill)
    @desagree_bills = @bill_supports.select { |s| s.support_type == "desagree" }.map(&:bill)
  end
end
