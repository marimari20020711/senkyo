require "open-uri"
require "nokogiri"
require "pdf-reader"
require "latest_session"
require "logger"

namespace :scrape do
  desc "Scrape Sangiin bills (参法・衆法・閣法)"
  task sangiin_hp_bills: :environment do
    # メイン処理の実行
    SangiinScraper.new.execute
  end
end

class SangiinScraper
  def initialize
    # デバッグモード設定
    @debug_mode = ENV['DEBUG'] == 'true'
    @logger = Logger.new($stdout)
    @logger.level = @debug_mode ? Logger::DEBUG : Logger::INFO
    # Politicianのnormalized_nameをキャッシュ（N+1防止）
    @politician_cache = Politician.all.index_by(&:normalized_name)
    @target_kinds = [
      "法律案（内閣提出）一覧",
      "法律案（衆法）一覧",
      "法律案（参法）一覧",   
      "予算一覧",
      "条約一覧",
      "予備費等支出承諾一覧",
      "国会の承認・承諾案件一覧",
      "歳入歳出決算一覧",
      "国有財産増減等計算書一覧",
      "国有財産無償貸付状況一覧",
      "ＮＨＫ決算一覧",
      "決議案一覧",
      "規則案一覧",
      "規程案一覧"
    ]
  end

    # メイン実行メソッド
  def execute
    start_time = Time.current
    @logger.info "[#{Time.current.strftime('%H:%M:%S')}] 参議院スクレイピング開始"
    
    # 対象とする国会回次（複数指定可能）
    begin
      target_sessions = setup_target_sessions
      return unless target_sessions
      @logger.info "対象国会: 第#{target_sessions.first}回〜第#{target_sessions.last}回"

      # 各国会の処理
      target_sessions.each do |session_number|
        process_session(session_number)
        @logger.info "完了: 第#{session_number}回国会"
      end

      duration = (Time.current - start_time).round(2)
      @logger.info "[#{Time.current.strftime('%H:%M:%S')}] スクレイピング完了 (#{duration}秒)"
      @logger.info "Sangiin scraping complete."

    rescue => e
      @logger.fatal "FATAL ERROR: スクレイピング全体エラー: #{e.message}"
      @logger.debug e.backtrace.first(5).join("\n") if @debug_mode
      exit 1
    end
  end

  private

  # 対象国会セッションの設定
  def setup_target_sessions  
    latest_session = LatestSession.fetch
    unless latest_session&.is_a?(Integer) && latest_session > 0
      @logger.error "ERROR: 最新国会情報の取得に失敗"
      exit 1
    end

    (210..latest_session).to_a.reverse
  end

  # 各国会の処理
  def process_session(session_number)
    session_url = "https://www.sangiin.go.jp/japanese/joho1/kousei/gian/#{session_number}/gian.htm"
    session_uri = URI.parse(session_url)
    doc = fetch_session_document(session_url)
    return unless doc
      
    #各テーブルの処理
    process_table_section(doc, session_uri)  
  end
        
  # セッション文書の取得    
  def fetch_session_document(session_url)
    begin
      # html = URI.open(session_url).read
      html = fetch_html(session_url)
      doc = Nokogiri::HTML(html)
      @logger.debug "[DEBUG] #{session_url} HTML length: #{html.size}" if @debug_mode
      return doc
    rescue => e
      @logger.warn "⚠️ 取得失敗: #{e.message}"
      return nil
    end
  end

  # テーブルセクションの処理
  def process_table_section(doc, session_uri)
    doc.css("h2.title_text").each do |h2|
      kind_index = h2.text.strip
      next unless @target_kinds.include?(kind_index)

      table = validate_table_structure(h2)
      next unless table

      headers = extract_table_headers(table)
      next unless headers

      col_indexes = build_column_indexes(headers)
      next unless validate_required_columns(col_indexes)

      # テーブル行の処理
      process_table_rows(table, col_indexes, session_uri)
    end
  end
      
    
  # テーブル構造の検証
  def validate_table_structure(h2)
    table = h2.xpath("following-sibling::table").first
    unless table
      @logger.warn "警告: table要素が見つかりませんでした"
      return nil
    end
    table
  end

  # テーブルヘッダーの抽出
  def extract_table_headers(table)
    headers = table.css("tr").first&.css("th")&.map { |th| th.text.strip }
    if headers.empty?
      @logger.warn "警告: テーブルヘッダーが見つかりませんでした"
      return nil
    end
    headers
  end

   # 列インデックスの構築
  def build_column_indexes(headers)
    {
      session: headers.index("提出回次"),
      number:  headers.index("提出番号"),
      title:   headers.find_index { |h| h&.include?("件名") },
    }
  end

   # 必須カラムの検証
  def validate_required_columns(col_indexes)
    required_columns = [:session, :title]
    missing_columns = required_columns.select { |col| col_indexes[col].nil? }
    if missing_columns.any?
      @logger.warn "警告: 必須カラムが見つかりません: #{missing_columns.join(', ')}"
      return false
    end
    true
  end

  # テーブル行の処理
  def process_table_rows(table, col_indexes, session_uri)
    table.css("tr")[1..].each do |tr|
      tds = tr.css("td")
      next if tds.size < col_indexes.values.compact.max.to_i + 1

      #col_indexesの値を使って各列の値を取得
      session = col_indexes[:session] && tds[col_indexes[:session]] ? 
                tds[col_indexes[:session]]&.text&.strip : nil

      number = col_indexes[:number] && tds[col_indexes[:number]] ? 
              tds[col_indexes[:number]]&.text&.strip : nil

      title_td = col_indexes[:title] && tds[col_indexes[:title]] ? 
              tds[col_indexes[:title]] : nil
  
      title_name = title_td&.text&.strip
      next unless title_td

      #タイトルリンク
      title_link_href = title_td&.at_css("a")&.[]("href")
      title_link = title_link_href ? URI.join(session_uri, title_link_href).to_s : nil
      next unless title_link

      # 提出法律案PDFリンク
      body_link_href = tds.map { |td| 
        td.css("a").find { |a| a.text.include?("提出法律案") }
      }.compact.first&.[]("href")
      body_link = body_link_href ? URI.join(session_uri, body_link_href).to_s : nil
      next unless body_link

      #議案要旨PDFリンク
    #   summary_link_href = tds.map { |td|
      #     td.css("a").find { |a| a.text.include?("議案要旨") }
      # }.compact.first&.[]("href")
    #   summary_link = summary_link_href ? URI.join(session_uri, summary_link_href).to_s : nil

    # 提出法律案PDFリンクの処理
      body_pdf_text = extract_body_pdf(body_link) if body_link
    
      bill_data = {
        session: session,
        number: number,
        title_name: title_name,
        title_link: title_link,
        body_link: body_link,
        body_pdf_text: body_pdf_text
      }
      process_bill_data(bill_data)
    end
  end
  
  # def extract_body_pdf(body_link)
  #   return nil unless body_link

    # begin      
    #   summary_pdf_io    = URI.open(summary_link)
    #   summary_reader    = PDF::Reader.new(summary_pdf_io)
    #   summary_pdf_text  = summary_reader.pages.map(&:text).join("\n\n")
    # 　bill.sangi_hp_summary_text = summary_pdf_text
    #     bill.save!
    #   rescue => e
    #     puts "⚠️ 議案要旨PDFを保存できませんでした: #{session}-#{number}"
    #     nil
    #   end
    # end 

  # PDFテキストの抽出
  def extract_body_pdf(body_link)
    return nil unless body_link

    begin
      body_pdf_io = URI.open(body_link)
      body_reader = PDF::Reader.new(body_pdf_io)
      body_reader.pages.map(&:text).join("\n\n")
    rescue => e
      @logger.warn "⚠️ PDF読み込み失敗 (#{body_link}): #{e.message}" if @debug_mode
      nil
    end
  end

  # 法案データの処理
  def process_bill_data(bill_data)
    session = bill_data[:session]
    number = bill_data[:number]
    title_name = bill_data[:title_name]
    title_link = bill_data[:title_link]
    body_link = bill_data[:body_link]
    body_pdf_text = bill_data[:body_pdf_text]

    title_doc = fetch_title_document(title_link)
    unless title_doc
      @logger.warn "⚠️ title_docの取得に失敗しました: #{session}-#{number}-#{title_name}"
      return 
    end

    kind = extract_bill_kind(title_doc)

    # Billレコードの安全な取得・初期化
    bill = find_or_initialize_bill(session, number, title_name, kind)
    return unless bill

    # 種別の取得と保存
    save_bill_data(bill, body_link, body_pdf_text, kind, session, number, title_name)
  
    # 採決結果の処理
    process_vote_results(title_doc, title_link, bill, session, number, title_name, kind)
  end

  # Billレコードの安全な取得・初期化
  def find_or_initialize_bill(session, number, title_name, kind)
    bill = Bill.find_or_initialize_by(
      session: session&.strip, 
      number: number&.strip, 
      title: title_name&.strip,
      kind: kind&.strip
    )
    bill
  rescue => e
    @logger.error "❌ Bill初期化エラー #{session}-#{number}: #{e.message}"
    nil
  end

  # タイトル詳細文書の取得
  def fetch_title_document(title_link)
    begin
      # 詳細ページ解析          
      title_html = URI.open(title_link)
      title_doc  = Nokogiri::HTML.parse(title_html)
      title_doc
    rescue => e
      @logger.warn "⚠️ 詳細ページ取得失敗 (#{title_link}): #{e.message}"
      nil
    end
  end

  # 法案種別の抽出
  def extract_bill_kind(title_doc)
    #"種別"を取得
    kind_row = title_doc.at_css("table.list_c tr:has(th:contains('種別'))") 
    kind = kind_row&.at_css("td")&.text&.strip
    kind
  end
          
  # 法案データの保存
  def save_bill_data(bill, body_link, body_pdf_text, kind, session, number, title_name)
    bill.sangi_hp_body_link = body_link
    # bill.sangi_hp_body_text = body_pdf_text

    # 変更がある場合のみ保存
    if bill.changed?
      begin
        bill.save!
        @logger.info "✅ Saved: #{bill.session}-#{bill.number}-#{bill.title} (kind: #{bill.kind})"
      rescue => e
        @logger.error "❌ Save failed for Bill #{session}-#{number}(kind: #{kind}): #{e.message}"
        return
      end
    else
      @logger.debug "⏭ Skip: No changes for #{session}-#{number}-#{title_name}(kind: #{kind})"
      #そのまま採決処理を続行
    end
  end

  # 採決結果の処理
  def process_vote_results(title_doc, title_link, bill, session, number, title_name, kind)
    #採決結果を取得・保存
    vote_row = title_doc.at_css("table.list_c tr:has(th:contains('採決方法'))")
    if vote_row
      vote_link_href = vote_row.at_css("a")&.[]("href")
      if vote_link_href
        vote_link = URI.join(title_link, vote_link_href).to_s
        vote_html = URI.open(vote_link)
        vote_doc  = Nokogiri::HTML(vote_html)
        vote_doc.css("li.giin").each do |li|

          name = li.at_css(".names")&.text&.strip&.gsub(/[[:space:]　]+/, "")
          next if name.blank?
          normalized_name = name.to_s.gsub(/[[:space:]]/, "")
          politician = @politician_cache[normalized_name]
          next if politician.nil?
          support_type =
            if li.at_css(".pros")&.text&.include?("賛成")
              "agree"
            elsif li.at_css(".cons")&.text&.include?("反対")
              "disagree"
            else
              nil
            end
          next if support_type.nil?
          BillSupport.find_or_create_by(
            bill: bill,
            supportable: politician,
            support_type: support_type
          )
        end
        @logger.info "🗳 Vote info saved for #{session}-#{number}-#{title_name}(kind: #{kind})"
      else
        @logger.info "🔕 採決リンクがありません: #{session}-#{number}-#{title_name}(kind: #{kind})"
      end
    else
      @logger.info "🔕 採決情報がありません: #{session}-#{number}-#{title_name}(kind: #{kind})"
    end
  end

  def fetch_raw_bytes(url)
    uri = URI.parse(url)
    Net::HTTP.get(uri) # 必ず ASCII-8BIT の String で返る
  end

  def fetch_html(url)
    raw_data = fetch_raw_bytes(url)
    safe_encode_to_utf8(raw_data)
  end

  def safe_encode_to_utf8(raw_data)
    return "" if raw_data.nil? || raw_data.empty?

    data = raw_data.dup.force_encoding('ASCII-8BIT')

    # Step 1: UTF-8チェック
    begin
      utf8_test = data.force_encoding('UTF-8')
      if utf8_test.valid_encoding?
        @logger.debug "✅ UTF-8として有効 → scrub処理で完了"
        @logger.info "[SUCCESS] 使用エンコーディング: UTF-8"
        return utf8_test.scrub('?')
      else
        @logger.warn "⚠️ UTF-8として無効 → 他のエンコーディングを試行"
      end
    rescue => e
      @logger.error "❌ UTF-8チェック失敗: #{e.message}"
    end
    
    # Step 2: Shift_JIS
    begin
      test_result = data.encode('UTF-8', 'Shift_JIS', invalid: :replace, undef: :replace, replace: '【REPLACED】')
      replacement_count = test_result.scan('【REPLACED】').length
      sjis_result = data.encode('UTF-8', 'Shift_JIS', invalid: :replace, undef: :replace, replace: '?')

      if sjis_result.valid_encoding?                     
        if replacement_count > 0
          @logger.warn "⚠️ Shift_JIS変換: #{replacement_count}文字を '?' に置換しました"
        else
          @logger.info "✅ Shift_JISで変換成功: #{sjis_result.length}文字"
        end
        @logger.info "[SUCCESS] 使用エンコーディング: Shift_JIS"
        return sjis_result.scrub('?')
      end
    rescue => e
      @logger.warn "⚠️ Shift_JIS変換失敗: #{e.class} - #{e.message}"
    end
    
    # Step 3: 他の候補
    fallback_encodings = ['Windows-31J', 'EUC-JP']
    fallback_encodings.each do |encoding|
      begin
        @logger.info "🔄 #{encoding}変換を試行"
        test_result = data.encode('UTF-8', encoding, invalid: :replace, undef: :replace, replace: '【REPLACED】')
        replacement_count = test_result.scan('【REPLACED】').length
        encoding_result = data.encode('UTF-8', encoding, invalid: :replace, undef: :replace, replace: '?')
        if encoding_result.valid_encoding? && encoding_result.length > 0
          @logger.info "✅ #{encoding}で変換成功 (#{encoding_result.length}文字)"
          @logger.info "[SUCCESS] 使用エンコーディング: #{encoding}"
          return encoding_result.scrub('?')
        end
      rescue => e
        @logger.error "❌ #{encoding}変換失敗: #{e.message}"
      end
    end

    # Step 4: クリーンアップ
    data = comprehensive_pattern_clean(data)
    data = clean_incomplete_multibyte_sequences(data)

    begin
      @logger.info "🔄 強制変換（最終手段）"
      result = data.force_encoding('UTF-8').scrub(' ')
      @logger.info "[SUCCESS] 使用エンコーディング: 強制UTF-8"
      return result
    rescue => e
      @logger.error "❌ 強制変換も失敗: #{e.message}"
      return ""
    end
  end

  def clean_incomplete_multibyte_sequences(data)
    while data.length > 0 && data[-1].ord > 127
      data = data[0..-2]
    end
    data
  end

  def comprehensive_pattern_clean(data)
    invalid_patterns = [
      /[\x80-\x9F][\x20-\x7F]/n,
      /[\x80-\x9F][\x80-\x9F]/n,
      /[\xFB-\xFF]./n,
      /[\x00-\x08\x0B\x0C\x0E-\x1F]/n
    ]
    invalid_patterns.each { |pattern| data.gsub!(pattern, ' ') }
    data
  end
end
