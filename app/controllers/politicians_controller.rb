class PoliticiansController < ApplicationController
  def show
    @politician = Politician.find(params[:id])
    @bill_supports = @politician.bill_supports.includes(:bill)

    @propose_bills = @bill_supports.select { |s| s.support_type == "propose" }.map(&:bill)
    @propose_agree_bills = @bill_supports.select { |s| s.support_type == "propose_agree" }.map(&:bill)
  end
end
