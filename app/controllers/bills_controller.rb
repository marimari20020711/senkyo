class BillsController < ApplicationController
  # 議案一覧（検索結果）
  def index
    @q = Bill.ransack(params[:q])
    @bills = @q.result(distinct: true).order(created_at: :desc)
    # @bills = @q.result.includes(bill_supports: :supportable)
    # @bills = @q.result.includes(bill_supports: :supportable).distinct.order(created_at: :desc)
  end

  # 議案詳細
  def show
    @bill = Bill.find(params[:id])

    # 提出会派、提出者、賛成者など
    supports = @bill.bill_supports.includes(:supportable)
    @propose_groups = supports.select { |s| s.supportable_type == "Group" && s.support_type == "propose" }
    @proposers = supports.select { |s| s.supportable_type == "Politician" && s.support_type == "propose" }
    @agreeers = supports.select { |s| s.supportable_type == "Politician" && s.support_type == "propose_agree" }
    @discussion_agree_groups = supports.select { |s| s.supportable_type == "Group" && s.support_type == "agree" }
    @discussion_disagree_groups = supports.select { |s| s.supportable_type == "Group" && s.support_type == "disagree" }
    @vote_agreeers = supports.select { |s| s.supportable_type == "Politician" && s.support_type == "agree" }
    @vote_disagreeers = supports.select { |s| s.supportable_type == "Politician" && s.support_type == "disagree" }
  
  end
end
