class LatestSession
  def self.fetch
    # セッション番号取得ロジック
    require "open-uri"
    require "nokogiri"

    menu_url = "https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/menu.htm"
    begin
    html = URI.open(menu_url).read
    doc = Nokogiri::HTML.parse(html)

    title = doc.at("title")&.text
    latest_session = title[/第(\d+)回国会/, 1]&.to_i

    raise "回次が取得できませんでした" unless latest_session

    puts "🆕 最新回次: #{latest_session}"
    rescue => e
    puts "⚠️ 最新回次取得失敗: #{e.message}"
    latest_session = 217 # フォールバック（手動）
    end
    latest_session
  end
end
    