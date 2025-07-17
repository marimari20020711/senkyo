class BillsController < ApplicationController
  # 議案一覧（検索結果）
  def index
    @bills = @bill_q.result(distinct: true).order(created_at: :desc)
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

  def autocomplete
    query = params[:query].to_s.strip

    Rails.logger.debug "🔍 オートコンプリートクエリ: #{query}"

    return render json: [] if query.empty?  # 空のクエリに対する処理

    results = Bill.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
                  .order("created_at DESC")
                  .limit(10)
                  .pluck(:title)
    render json: results.map { |title| { name: title } }
  end

#   def autocomplete
#     query = params[:query].to_s.strip

#     # Rails.logger.debug "🔍 オートコンプリートクエリ: #{query}"

#     return render plain: "" if query.blank?  # 空のクエリに対する処理

#     results = Bill.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
#                   .order("created_at DESC")
#                   .limit(10)
#                   .pluck(:title)
#     render inline: <<-ERB, layout: false, locals: { results: results }
#       <% results.each do |title| %>
#         <li class="list-group-item" role="option" data-autocomplete-value="<%= title %>"><%= title %></li>
#       <% end %>
#     ERB
#   end
end
