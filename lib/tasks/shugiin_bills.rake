require "open-uri"
require "nokogiri"
require "latest_session"
require "net/http"   # fetch_raw_bytes 用

namespace :scrape do
  desc "Scrape Shugiin bills (衆法・参法・閣法)"
  task shugiin_hp_bills: :environment do
    ShugiinScraper.new.execute
  end
end

class ShugiinScraper
  def initialize
    @debug_mode = ENV['DEBUG'] == "true"
    @politician_cache = Politician.all.index_by(&:normalized_name)
    range = setup_target_sessions
    @sessions_map = {
      "閣法" => range,
      "衆法" => range,
      "参法" => range,
      "予算" => range,
      "条約" => range,
      "承認" => range,
      "承諾" => range,
      "決算" => range,
      "決議" => range,
      "規則" => range,
      "規程" => range
    }

    @caption_map = {
       "閣法" => ["閣法の一覧"], 
       "衆法" => ["衆法の一覧"],
       "参法" => ["参法の一覧"],
       "予算" => ["予算の一覧"],
       "条約" => ["条約の一覧"],
       "承認" => ["承認の一覧"], 
       "承諾" => ["承諾の一覧"],
       "決算" => ["決算その他"], 
       "決議" => ["決議の一覧"],
       "規則" => ["規則の一覧"],
       "規程" => ["規程の一覧"]
      }
    
    @kind_mapping = {
        "閣法" => "法律案（内閣提出）",
        "衆法" => "法律案（衆法）",
        "参法" => "参法律案（参法）",
        "決議" => "決議案",
        "規則" => "規則案",
        "規程" => "規程案"
      }
  end

  # 国会回次取得
  def setup_target_sessions
    latest_session = LatestSession.fetch
    unless latest_session&.is_a?(Integer) && latest_session > 0
      puts "ERROR: 最新国会情報の取得に失敗"
      exit 1
    end
    (211..latest_session).to_a.reverse
  end

  # メイン処理
  def execute
    start_time = Time.current
    puts "[#{Time.current.strftime('%H:%M:%S')}] 衆議院スクレイピング開始"
    
    begin
      target_sessions = setup_target_sessions
        return unless target_sessions
      puts ("対象国会: 第#{target_sessions.first}回〜第#{target_sessions.last}回")

      @sessions_map.each do |table_name, sessions|
        sessions.each do |session_number|
          process_session(table_name, session_number)
          puts "完了: #{table_name} for 第#{session_number}回国会"
        end
      end
      duration = (Time.current - start_time).round(2)
      puts "[#{Time.current.strftime('%H:%M:%S')}] スクレイピング完了 (#{duration}秒)"
    rescue => e
      puts "FATAL ERROR: #{e.message}"
      puts e.backtrace.first(5).join("\n") if @debug_mode
      exit 1
    end
  end

  # 各セッション処理
  def process_session(table_name, session_number)
    session_url = "https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/kaiji#{session_number}.htm"
    session_uri = URI.parse(session_url)
    doc = fetch_session_document(session_url)
    return unless doc
      
    process_table_section(doc, session_uri, table_name, session_number)
  end

  # HTML取得
  def fetch_session_document(session_url)
    html = URI.open(session_url).read
    doc = Nokogiri::HTML(html)
    puts "[DEBUG] #{session_url} HTML length: #{html.size}" if @debug_mode
    return doc
    rescue => e
    puts "⚠️ 取得失敗: #{e.message}"
    return nil
  end

  # caption から正規化された名前を取得
  def normalize_caption(caption_text)
    @caption_map.each do |normalized, variants|
      return normalized if variants.any? { |v| caption_text.include?(v) }
    end
    nil
  end

  # テーブル処理
  def process_table_section(doc, session_url, table_name, session_number)
    # table_name（"承諾" など）に対応するテーブルを caption から探す
    target_table = doc.css("table.table").find do |table|
      caption_text = table.at_css("caption")&.text&.strip
      next false unless caption_text
      normalize_caption(caption_text) == table_name
    end

    # tableの存在チェック（安全呼び出し演算子使用）
    unless target_table
      puts "警告: テーブル '#{table_name}' が見つかりませんでした"
      return
    end

    # ヘッダーの取得（安全呼び出し演算子使用）
    headers = target_table.css("th")&.map { |th| th&.text&.strip } || []
    if headers.empty?
      puts "警告: テーブルヘッダーが見つかりませんでした"
      return
    end
    col_indexes = build_column_indexes(headers)
    # 行データ処理
    process_table_rows(target_table, col_indexes, session_url, session_number, table_name)
  end

  # カラムインデックスの取得（存在チェック付き）
  def build_column_indexes(headers)  
    col_indexes = {
      session: headers.find_index { |h| h&.include?("提出回次") },
      number: headers.find_index { |h| h&.include?("番号") },
      title: headers.find_index { |h| h&.include?("議案件名") },
      status: headers.find_index { |h| h&.include?("審議状況") },
      progress: headers.find_index { |h| h&.include?("経過情報") },
      body: headers.find_index { |h| h&.include?("本文情報") }
    }
    col_indexes
  end

   # 行処理
  def process_table_rows(target_table, col_indexes, session_url, session_number, table_name)
    target_table.css("tr")[1..].each do |tr|
      # tdの存在チェック
      tds = tr&.css("td") || []
      next if tds.empty? 
      puts "議案カラム処理開始: 議案名= #{tds[col_indexes[:title]]&.text&.strip}, (回次: #{tds[col_indexes[:session]]&.text&.strip}, テーブル名: #{table_name})"

      # 各セルのデータを安全に取得
      session = col_indexes[:session] && tds[col_indexes[:session]] ? 
                tds[col_indexes[:session]]&.text&.strip : nil
      
      number = col_indexes[:number] && tds[col_indexes[:number]] ? 
              tds[col_indexes[:number]]&.text&.strip : nil
      
      title = col_indexes[:title] && tds[col_indexes[:title]] ? 
              tds[col_indexes[:title]]&.text&.strip : nil
      
      discussion_status = col_indexes[:status] && tds[col_indexes[:status]] ? 
                          tds[col_indexes[:status]]&.text&.strip : nil

      # リンクの安全な取得
      progress_href = nil
      if col_indexes[:progress] && tds[col_indexes[:progress]]
        progress_link = tds[col_indexes[:progress]]&.at_css("a")
        progress_href = progress_link&.[]("href")
      end
      
      body_href = nil
      if col_indexes[:body] && tds[col_indexes[:body]]
        body_link = tds[col_indexes[:body]]&.at_css("a")
        body_href = body_link&.[]("href")
      end
      
      # 必須カラムの存在チェック
      required_columns = [:session, :title]
      missing_columns = required_columns.select { |col| col_indexes[col].nil? }
      if missing_columns.any?
        puts "警告: 必須カラムが見つかりません: #{missing_columns.join(', ')}"
        next
      end

      # 経過データの取得
      progress_data = fetch_progress_data(session_url, progress_href, table_name) if progress_href&.present? 
      # 本文データの取得
      body_data = fetch_shugiin_body_data(session_url, body_href) if body_href&.present? 
      # kindのマッピング
      kind = progress_data[:kind]
      
      # 基本属性の設定
      attributes = {
        discussion_status: discussion_status&.strip,
      }

      # attributesにbody_dataをマージ            
      if body_data&.is_a?(Hash)
        attributes.merge!(body_data)
      end
      
      bill = find_or_initialize_bill(session, number, title, kind)

      # bill_saved = false
      # 属性を設定して変更チェック
      bill.assign_attributes(attributes)
      # 変更がある場合のみ保存
      if bill.changed?
        
        begin
          bill.save!
          # bill_saved = true
          puts "✅ Saved: #{session}-#{number}: #{title} [#{kind}]"
        rescue => e
          # bill_saved = true
          puts "❌ Save failed for Bill #{session}-#{number}-#{title}(kind: #{kind}): #{e.message}"
          next
           # エラーの場合は次の処理へ
        end
      else  
        puts "⏭ Skip: No changes for #{session}-#{number}-#{title}(kind: #{kind})"
         # 変更がない場合は次の処理へ
      end

      # 関連データの保存（安全に実行）
      # if bill_saved
      begin  
        proposer_groups = progress_data[:proposer_groups] || []
        proposer_names = progress_data[:proposer_names] || []
        agreeer_names = progress_data[:agreeer_names] || []
        agree_groups = progress_data[:agree_groups] || []
        disagree_groups = progress_data[:disagree_groups] || []
        save_bill_supports(bill, proposer_groups, proposer_names, agreeer_names, agree_groups, disagree_groups)
        
      puts "[#{kind}] 🔗 関連データ保存完了: #{session}-#{number}"
      rescue => e
        puts "❌ 関連データ保存エラー: #{e.message} - #{session}-#{number}: #{title}"
      end
    # end
    end
  end

  # Billレコードの安全な取得・初期化
  def find_or_initialize_bill(session, number, title, kind)
    Bill.find_or_initialize_by(
      session: session&.strip, 
      number: number&.strip, 
      title: title&.strip,
      kind: kind&.strip
    )
  rescue => e
    puts "❌ Bill初期化エラー #{session}-#{number}: #{e.message}"
    nil
  end

  # progress_hrefの処理
  def fetch_progress_data(session_url, progress_href, table_name)
    begin
      progress_data = fetch_shugiin_progress_data(session_url, progress_href, table_name)

      # マッピング処理
      if @kind_mapping && progress_data[:kind]
        progress_data[:kind] = @kind_mapping[progress_data[:kind]] || progress_data[:kind]         
      end

      progress_data
    rescue => e
      puts "❌エラー: progress_data取得に失敗しました: #{e.message}"
      default_progress_data(table_name)
    end
  end

  # Shugiinの進捗データ取得
  def fetch_shugiin_progress_data(session_url, href, table_name)
    progress_url = URI.join(session_url, href).to_s

    begin
      puts "[DEBUG] URL取得開始: #{progress_url}"
      raw_data = fetch_raw_bytes(progress_url)
      puts "[DEBUG] URL取得完了: #{raw_data.bytesize} bytes"
      puts "📊 生データサイズ: #{raw_data.length}バイト"
    
    # デバッグ: 問題バイト検出
    invalid_bytes = raw_data.bytes.select { |byte| byte > 127 && !raw_data.force_encoding('UTF-8').valid_encoding? }
    if invalid_bytes.any?
      puts "⚠️ 無効バイト検出: #{invalid_bytes.size}個"
    end

     # 🔧 多段階エンコーディング処理
    progress_html = safe_encode_to_utf8(raw_data)
      puts "✅ 変換完了: #{progress_html.length}文字"
      
    rescue => e
      puts "❌ progressデータ取得エラー: #{e.message}"
      puts e.backtrace.join("\n")
      return default_progress_data(table_name)
    end

    progress_doc = Nokogiri::HTML(progress_html)
    tables = progress_doc.css("table")

    # デバッグ出力を追加
    puts "🔍 テーブル数: #{tables.length}"

    data = {}
    tables[0]&.css("tr")&.each do |row|
      th = row.at_css("td:first-child") || row.at_css("th")
      td = row.at_css("td:last-child")
      next unless th && td
      data[th.text.strip] = td.text.strip
    end

    # 重要なデバッグ出力
    # puts "📋 data内容: #{data.keys}"
    puts "📝 議案提出者: '#{data.fetch("議案提出者", "")}'"

    data2 = {}
    if tables[1]&.css("tr")
      tables[1]&.css("tr")&.each do |row|
        tds = row.css("td")
        next unless tds.size == 2
        data2[tds[0].text.strip] = tds[1].text.strip
      end
    end

    puts "📋 data2内容: #{data2.keys}"
    puts "📝 議案提出者一覧: '#{data2["議案提出者一覧"]}'"

    progress_data = {
      kind: data.fetch("議案種類", "").strip&.presence || table_name,
      proposer_groups: split_and_clean(data.fetch("議案提出会派", "")),
      proposer_names: begin
        if data2["議案提出者一覧"].present?
          split_and_clean(data2["議案提出者一覧"]).map { |s| s.sub(/君\z/, "") }
        else
          extract_names_from_text(data.fetch("議案提出者", ""))
        end
      end,
      agreeer_names: split_and_clean(data2.fetch("議案提出の賛成者", "")).map { |s| s.sub(/君\z/, "") },
      agree_groups: split_and_clean(data.fetch("衆議院審議時賛成会派", "")),
      disagree_groups: split_and_clean(data.fetch("衆議院審議時反対会派", ""))
      }
    progress_data  
  end

  def default_progress_data(table_name)
    mapped_kind = @kind_mapping ? (@kind_mapping[table_name] || table_name) : table_name
    {
      kind: mapped_kind,
      proposer_groups: [],
      proposer_names: [],
      agreeer_names: [],
      agree_groups: [],
      disagree_groups: []
    }
  end

  def extract_names_from_text(text)

    # デバッグ情報を追加
    puts "🔍 extract_names_from_text呼び出し: '#{text}'"
    
    # 早期リターンでnilや空文字をガード
    if text.blank?
      puts "⚠️ テキストが空です"
      return []
    end

    begin
       # 「〇〇君外〇名」や「〇〇君」を除去して名前だけにする
      names = text.to_s
                  .split(/、|,|;/) # 複数区切りに対応
                  .map do |s|
                    s = s.sub(/君外[0-9０-９一二三四五六七八九十]+名/, "") # 君外〇名を削除
                    s = s.sub(/君\z/, "")                                  # 君を削除
                    s.strip
                  end
                  .reject(&:empty?)  # 空文字を除去

      # 配列の各要素のスペースも除去
      names.map { |n| n.gsub(/[[:space:]]/, "") }
    rescue => e
      puts "❌ 名前抽出エラー: #{e.message} - 入力: #{text.inspect}"
      []
    end
  end

  def fetch_shugiin_body_data(session_url, body_href)

    # 入力値の安全性チェック
    unless session_url&.present? && body_href&.present?
      puts "⚠️ 無効な body URL情報: session_url=#{session_url}, body_href=#{body_href}"
      return default_body_data
    end

    body_url = URI.join(session_url, body_href).to_s

    begin
      body_html = fetch_html(body_url)
      body_doc = Nokogiri::HTML(body_html)
      
      unless body_doc
        puts "❌ HTMLパースに失敗: #{body_url}"
        return default_body_data
      end

    rescue => e
      puts "❌ Body HTML取得エラー: #{body_url} (#{e.message})"
      return default_body_data
    end

    # 要綱データの安全な取得
    summary_data = extract_summary_data(body_doc, body_url)
    
    # 法案本文データの安全な取得
    body_data = extract_body_data(body_doc, body_url)

    {
      summary_link: summary_data[:link]&.strip.presence || nil,
      summary_text: summary_data[:text]&.strip.presence || nil,
      body_link: body_data[:link]&.strip.presence || nil,
      # body_text: body_data[:text]&.strip.presence || nil
    }
  end

  private

  # デフォルトの空データを返す
  def default_body_data
    {
      summary_link: nil,
      summary_text: nil,
      body_link: nil,
      body_text: nil
    }
  end

  # 要綱データを安全に抽出
  def extract_summary_data(body_doc, body_url)
    
    youkou_link = body_doc&.css("a")&.find { |a| a&.text&.include?("要綱") }  
    unless youkou_link&.[]("href")
      puts "要綱リンクなし"
      return { link: nil, text: nil }
    end

    begin
      summary_link = URI.join(body_url, youkou_link["href"]).to_s  
      summary_doc = Nokogiri::HTML(fetch_html(summary_link))
      h2 = summary_doc&.at_css("h2#TopContents")
      
      unless h2
        puts "⚠️ 要綱のh2要素が見つかりません"
        return { link: summary_link, text: nil }
      end

      summary_text = extract_text_content(h2)
      puts "✅ 要綱テキスト抽出完了: #{summary_text&.length || 0}文字" 
      { link: summary_link, text: summary_text }
      
    rescue => e
      puts "❌ 要綱データ取得エラー: #{e.message}"
      puts e.backtrace.join("\n")
      { link: nil, text: nil }
    end
  end

  # 法案本文データを安全に抽出
  def extract_body_data(body_doc, body_url)
    houan_link = body_doc&.css("a")&.find { |a| a&.text&.include?("提出時法律案") } 
    unless houan_link&.[]("href")
      puts "法案本文リンクなし"
      return { link: nil, text: nil }
    end

    body_link = URI.join(body_url, houan_link["href"]).to_s
    unless body_link
      puts "法案本文リンクなし"
      return { link: nil, text: nil }
    end

    houan_body_doc = Nokogiri::HTML(fetch_html(body_link))
    h2 = houan_body_doc&.at_css("h2#TopContents")
  
    unless h2
      puts "⚠️ 法案本文のh2要素が見つかりません"
      return { link: body_link, text: nil }
    end

    ps = h2.xpath("following-sibling::p")
    body_text = ps&.map { |p| p&.text&.strip }&.compact&.join("\n\n")
    { link: body_link, text: body_text }
      
  end

  # テキストコンテンツを安全に抽出
  def extract_text_content(h2_element)
    return nil unless h2_element
    summary_text = ""
    node = h2_element
    
    while node = node&.next_element
      break if node&.name =~ /^h\d$/i || node&.name == "div"
      text_content = node&.text&.strip
      summary_text << "#{text_content}\n\n" if text_content&.present?
    end
    
    summary_text.present? ? summary_text : nil
  end


  def save_bill_supports(bill, proposer_groups, proposer_names, agreeer_names, agree_groups, disagree_groups)
    puts "💾 BillSupports保存開始: Bill ID=#{bill&.id}"
    
    # 入力値の安全性チェック
    unless bill&.persisted?
      puts "❌ 無効なBillオブジェクト: #{bill.inspect}"
      return false
    end

    begin
      # 各種サポートデータの保存実行
      save_group_proposals(bill, proposer_groups)        # 提出会派
      save_politician_proposals(bill, proposer_names) # 提出者
      save_politician_agreements(bill, agreeer_names) # 賛成者
      save_group_agreements(bill, agree_groups)      # 審議時賛成会派
      save_group_disagreements(bill, disagree_groups) # 審議時反対会派
      
      puts "✅ BillSupports保存完了: Bill ID=#{bill.id}"
      true
      
    rescue => e
      puts "❌ BillSupports保存エラー: #{e.message}"
      puts "📊 エラー詳細: Bill=#{bill&.id}, Groups=#{proposer_groups&.length}, Proposers=#{proposer_names&.length}"
      false
    end
  end

  def split_and_clean(text)
    text.to_s.split(/、|,|;/).map(&:strip).reject(&:empty?)
  end

  # 提出会派の情報を保存
  def save_group_proposals(bill, proposer_groups)
    return unless proposer_groups&.is_a?(Array)
    
    proposer_groups.each_with_index do |g_name, index|
      next if g_name.blank?
      begin
        group = find_or_create_group(g_name)
        unless group
          puts "  ⚠️ [#{index + 1}/#{proposer_groups.length}] 提出会派未発見: #{g_name}"
          next
        end
        create_bill_support(bill, group, "propose", "提出会派")
        # puts "  ✅ [#{index + 1}/#{proposer_groups.length}] 提出会派: #{g_name}" 
      rescue => e
        puts "  ❌ [#{index + 1}/#{proposer_groups.length}] 提出会派エラー: #{g_name} (#{e.message})"
      end
    end
  end

  # 提出者の情報を保存
  def save_politician_proposals(bill, proposer_names)
    return unless proposer_names&.is_a?(Array)
    proposer_names.each_with_index do |p_name, index|
      next if p_name.blank?
      
      begin
        politician = find_politician_by_name(p_name)
        if politician
          create_bill_support(bill, politician, "proposer_names", "提出者")
          # puts "  ✅ [#{index + 1}/#{proposer_names.length}] 提出者: #{p_name}"
        else 
          # politician が見つからなくても raw_politician で保存
          BillSupport.find_or_create_by!(
            bill: bill,
            raw_politician: p_name,  
            support_type: "proposer_names"
          )
          puts "[#{index + 1}/#{proposer_names.length}] 提出者: #{p_name}"
        end
      rescue => e
        puts "  ❌ [#{index + 1}/#{proposer_names.length}] 提出者エラー: #{p_name} (#{e.message})"
      end
    end
  end

  # 賛成者の情報を保存
  def save_politician_agreements(bill, agreeer_names)
    return unless agreeer_names&.is_a?(Array)
    
    agreeer_names.each_with_index do |a_name, index|
      next if a_name.blank? 
      begin
        politician = find_politician_by_name(a_name) 
        unless politician
          puts "  ⚠️ [#{index + 1}/#{agreeer_names.length}] 賛成者未発見: #{a_name}"
          next
        end 
        create_bill_support(bill, politician, "propose_agree", "賛成者")
        # puts "  ✅ [#{index + 1}/#{agreeer_names.length}] 賛成者: #{a_name}"
      rescue => e
        puts "  ❌ [#{index + 1}/#{agreeer_names.length}] 賛成者エラー: #{a_name} (#{e.message})"
      end
    end
  end

  # 審議時賛成会派の情報を保存
  def save_group_agreements(bill, agree_groups)
    return unless agree_groups&.is_a?(Array)
    agree_groups.each_with_index do |g_name, index|
      next if g_name.blank?
      
      begin
        group = find_or_create_group(g_name)
        next unless group
        create_bill_support(bill, group, "agree", "審議時賛成会派")
        # puts "  ✅ [#{index + 1}/#{agree_groups.length}] 審議時賛成会派: #{g_name}"
      rescue => e
        puts "  ❌ [#{index + 1}/#{agree_groups.length}] 審議時賛成会派エラー: #{g_name} (#{e.message})"
      end
    end
  end

  # 審議時反対会派の情報を保存
  def save_group_disagreements(bill, disagree_groups)
    return unless disagree_groups&.is_a?(Array)
    disagree_groups.each_with_index do |g_name, index|
      next if g_name.blank?
      
      begin
        group = find_or_create_group(g_name)
        next unless group
        create_bill_support(bill, group, "disagree", "審議時反対会派")
        # puts "  ✅ [#{index + 1}/#{disagree_groups.length}] 審議時反対会派: #{g_name}"
      rescue => e
        puts "  ❌ [#{index + 1}/#{disagree_groups.length}] 審議時反対会派エラー: #{g_name} (#{e.message})"
      end
    end
  end

  # 政治家を名前で検索するメソッド
  def find_politician_by_name(name)
    return nil if name.blank?
    
    # 名前の正規化処理
    normalized_name = normalize_politician_name(name)

    # Politicianのnormalized_nameをキャッシュ（N+1防止）
    politician = @politician_cache[normalized_name]
    
    unless politician
      puts "⚠️ 政治家未発見: #{name} "
    end
    
    politician
  end

  # 政治家名を正規化するメソッド
  def normalize_politician_name(name)
    return "" if name.blank?
    # スペースの除去と統一化
    name.to_s
        .gsub(/\s+/, "")          # 全てのスペース（半角・全角）を除去
        .strip                     # 前後の空白除去
  end

  # 会派を検索または作成するメソッド
  def find_or_create_group(name)
    return nil if name.blank?
    
    # 既存の会派を検索、なければ作成
    group = Group.find_or_create_by(name: name) do |g|
      g.name = name
    end
    group
  rescue => e
    puts "❌ 会派作成エラー: #{name} (#{e.message})"
    nil
  end

  # BillSupportレコードを作成するメソッド
  def create_bill_support(bill, supportable, support_type, description)
    
    begin
        BillSupport.find_or_create_by!(
          bill: bill, 
          supportable: supportable, 
          support_type: support_type
        )
      # puts "✅ #{description}保存完了: #{supportable.name}"
      
    rescue ActiveRecord::RecordInvalid => e
      puts "❌ #{description}保存エラー: #{supportable&.name} (#{e.message})"
      raise e
    end
  end
end

def fetch_raw_bytes(url)
  uri = URI.parse(url)
  Net::HTTP.get(uri) # これは必ず ASCII-8BIT の String で返る
end

def fetch_html(url)
  raw_data = fetch_raw_bytes(url)
  safe_encode_to_utf8(raw_data)
end

def safe_encode_to_utf8(raw_data)
  return "" if raw_data.nil? || raw_data.empty?

  data = raw_data.dup.force_encoding('ASCII-8BIT')

  # 🚀 Step 1: UTF-8チェック（最優先・最高速）
  begin
    utf8_test = data.force_encoding('UTF-8')
    if utf8_test.valid_encoding?
      puts "✅ UTF-8として有効 → scrub処理で完了"
      puts "[SUCCESS] 使用エンコーディング: UTF-8"
      return utf8_test.scrub('?')
    else
      puts "⚠️ UTF-8として無効 → 他のエンコーディングを試行"
    end
  rescue => e
    puts "❌ UTF-8チェック失敗: #{e.message}"
  end
  
  # Step 2: Shift_JISとして試行
  begin
    test_result = data.encode('UTF-8', 'Shift_JIS', 
                          invalid: :replace, 
                          undef: :replace, 
                          replace: '【REPLACED】')

    replacement_count = test_result.scan('【REPLACED】').length
    
    # 実際の変換（? で置換）
    sjis_result = data.encode('UTF-8', 'Shift_JIS', 
                             invalid: :replace, 
                             undef: :replace, 
                             replace: '?')

    if sjis_result.valid_encoding?                     
      if replacement_count > 0
        puts "⚠️ Shift_JIS変換:  #{replacement_count}文字を '?' に置換しました"
      else
        puts "✅ Shift_JISで変換成功: #{sjis_result.length}文字"
      end
      puts "[SUCCESS] 使用エンコーディング: Shift_JIS"
      return sjis_result.scrub('?')
    else
      puts "⚠️ Shift_JIS変換後も無効"
    end
  rescue => e
     # 呼び出し元に伝播しない
    puts "⚠️ Shift_JIS変換失敗: #{e.class} - #{e.message}"
  end
  
  # 🔄 Step 3: 他のエンコーディング試行（UTF-8が無効な場合のみ）
  fallback_encodings = ['Windows-31J', 'EUC-JP']
  fallback_encodings.each do |encoding|
    begin
      puts "🔄 #{encoding}変換を試行"
      test_result = data.encode('UTF-8', encoding, 
                                 invalid: :replace, 
                                 undef: :replace, 
                                 replace: '【REPLACED】')
      
      replacement_count = test_result.scan('【REPLACED】').length
    
      # 実際の変換（? で置換）
      encoding_result = data.encode('UTF-8', encoding, 
                              invalid: :replace, 
                              undef: :replace, 
                              replace: '?')
      
      # 結果の妥当性チェック
      if encoding_result.valid_encoding? && encoding_result.length > 0
        if replacement_count > 0
          puts "⚠️ #{encoding}変換:  #{replacement_count}を '?' に置換しました"
        else
          puts "✅ #{encoding}で変換成功: #{encoding_result.length}文字"
        end
        puts "[SUCCESS] 使用エンコーディング: #{encoding}"
        return encoding_result.scrub('?')
      else
        puts "⚠️ #{encoding}: 結果が不十分 (#{result.length}文字)"
      end
    rescue => e
      puts "❌ #{encoding}変換失敗: #{e.message}"
    end
  end

  # 🎯 包括的パターンクリーニング（最優先）
  data = comprehensive_pattern_clean(data)
  
  # 残りのクリーニング
  data = clean_incomplete_multibyte_sequences(data)

  # 🆘 Step 4: 最終手段（すべて失敗した場合）
  begin
    puts "🔄 強制変換（最終手段）"
    result = data.force_encoding('UTF-8').scrub(' ')
    puts "[SUCCESS] 使用エンコーディング: 強制UTF-8"
    return result
  rescue => e
    puts "❌ 強制変換も失敗: #{e.message}"
    return ""
  end
end

# 補助メソッド：不完全なマルチバイト文字列をクリーンアップ
def clean_incomplete_multibyte_sequences(data)
  # 文字境界で切り捨てられた可能性のある末尾バイトを除去
  while data.length > 0 && data[-1].ord > 127
    data = data[0..-2]
  end
  data
end

def comprehensive_pattern_clean(data)
  # 🚀 無効パターンを一括処理
  invalid_patterns = [
    /[\x80-\x9F][\x20-\x7F]/n,           # \x87@ 系
    /[\x80-\x9F][\x80-\x9F]/n,           # 連続無効バイト
    /[\xFB-\xFF]./n,                     # \xFB\xFC 系（重要！）
    /[\x00-\x08\x0B\x0C\x0E-\x1F]/n     # 制御文字
  ]
  
  invalid_patterns.each do |pattern|
    data.gsub!(pattern, ' ')
  end
  
  data
end