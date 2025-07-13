class SpeechesController < ApplicationController
  def index
    @keyword = params[:keyword]

    if @keyword.present?
      @speeches = KokkaiApiClient.fetch_speeches(
        politician_name: nil, # 指定しない
        start_date: 5.years.ago.to_date,
        end_date: Date.today,
        keyword: @keyword
      )
      # ↓ speaker名とPoliticianモデルをマッピング
      speaker_names = @speeches.map { |s| s["speaker"].to_s.delete(" ") }.uniq
      @speaker_politicians = Politician.where(normalized_name: speaker_names)
                                       .index_by(&:normalized_name)
    else
      @speeches = []
      @speaker_politicians = {}
    end
  end
end
