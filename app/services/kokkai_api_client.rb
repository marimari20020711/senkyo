# app/services/kokkai_api_client.rb
require 'net/http'
require 'uri'
require 'json'

class KokkaiApiClient
  BASE_URL = "https://kokkai.ndl.go.jp/api/speech"

  def self.fetch_speeches(politician_name: nil, start_date:, end_date:, keyword: nil)
    uri = URI(BASE_URL)
    params = {
      from: start_date.to_s,
      until: end_date.to_s,
      recordPacking: "json",
      maximumRecords: 50
    }

    # ✅ 議員名は「speaker」として指定（API仕様）
    params[:speaker] = politician_name if politician_name.present?

    # ✅ キーワードは「any」として指定（API仕様）
    params[:any] = keyword if keyword.present?

    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)

    return [] unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body)
    data["speechRecord"] || []
  end
end
