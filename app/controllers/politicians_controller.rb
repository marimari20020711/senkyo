class PoliticiansController < ApplicationController
  def index
    @q = Politician.ransack(params[:q])
    @politicians = @q.result(distinct: true)
  end

  def show
    @politician = Politician.find(params[:id])

    @propose_bills = @politician.bill_supports
      .where(support_type: "propose")
      .includes(:bill)
      .map(&:bill)

    @propose_agree_bills = @politician.bill_supports
      .where(support_type: "propose_agree")
      .includes(:bill)
      .map(&:bill)

    @vote_agree_bills = @politician.bill_supports
      .where(support_type: "agree")
      .includes(:bill)
      .map(&:bill)

    @vote_disagree_bills = @politician.bill_supports
      .where(support_type: "disagree")
      .includes(:bill)
      .map(&:bill)
    
    normalized_name = @politician.normalized_name
    @speeches = KokkaiApiClient.fetch_speeches(
      politician_name: normalized_name,
      start_date: 5.years.ago.to_date,
      end_date: Date.today
    )
  end
end
