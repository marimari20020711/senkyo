class BillsController < ApplicationController
  def index
    @q = Bill.ransack(params[:q])
    @bills = @q.result.includes(bill_supports: :supportable)
  end
end
